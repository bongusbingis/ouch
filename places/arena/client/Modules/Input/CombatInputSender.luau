--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local InputBuffer = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input"):WaitForChild("InputBuffer")
)
local AimDirector = require(script.Parent.AimDirector)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local CombatState = require(script.Parent.Parent.Presentation.CombatState)

-- Sends throw and catch intent to the server. Intent only: the server decides
-- whether the action is legal, where it starts from, and what it hits.
--
-- Input is classified upstream in PlayerModule.Combat, which owns every device
-- and every touch. What arrives here is already device-independent intent, so
-- there is one code path regardless of whether the player tapped, clicked,
-- flicked or pulled a trigger.
--
-- There are only two throws: a normal one and a charged one. Every gesture that
-- is not a hold produces the normal throw, so a tap, a click, a bottom swipe and
-- a trigger pull all arrive here identically.

local CombatInputSender = {}

local started = false
local listeners: { (string) -> () } = {}
local intentDisconnect: (() -> ())? = nil
local heartbeat: RBXScriptConnection? = nil
local buffer = InputBuffer.new()
-- How a throw was performed, carried alongside the action so a buffered input
-- replays as the same throw the player made.
type Style = { targetId: string?, charge: number? }

local pendingStyle: Style? = nil

-- Lets presentation react to the local player's own intent at press time,
-- without a second place detecting the same input edge.
function CombatInputSender.onIntent(listener: (string) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

local function notify(kind: string)
	for _, listener in listeners do
		local ok, err = pcall(listener, kind)
		if not ok then
			warn(`[CombatInputSender] intent listener error: {err}`)
		end
	end
end

-- A ball is inbound when projecting its current velocity forward passes close
-- to the player. Only used to decide which intent a tap means; the server still
-- validates the catch independently.
local function ballIncoming(): boolean
	local settings = MobileInput.ContextualCatch
	if not settings.Enabled then
		return false
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local balls = Workspace:FindFirstChild("Balls")
	if root == nil or not root:IsA("BasePart") or balls == nil then
		return false
	end

	for _, ball in balls:GetChildren() do
		if not ball:IsA("BasePart") then
			continue
		end
		local velocity = ball:GetAttribute("vel")
		if typeof(velocity) ~= "Vector3" or velocity.Magnitude <= 1e-3 then
			continue
		end
		local toPlayer = root.Position - ball.Position
		-- Moving away rather than toward us.
		if toPlayer:Dot(velocity) <= 0 then
			continue
		end
		local projected = ball.Position + velocity * settings.LookaheadSeconds
		local closest = (projected - root.Position).Magnitude
		if math.min(closest, toPlayer.Magnitude) <= settings.ApproachRadiusStuds then
			return true
		end
	end
	return false
end

-- With no ball held a tap is ambiguous between swinging and catching. The
-- hammer stays the default; catch only wins when something is genuinely inbound.
local function intentForTap(): string
	if CombatState.canThrowBall() then
		return "Throw"
	end
	return if ballIncoming() then "Catch" else "Throw"
end

-- Equip is a request like any other: the server owns the equipped weapon and
-- projects it back. Nothing is predicted here, so a rejected or rate-limited
-- equip simply leaves the HUD showing what the player actually has.
local function equip(weapon: string)
	Network.fireServer("SubmitWeaponEquip", weapon)
end

local function send(kind: string, style: Style)
	local aimDir = AimDirector.currentAim()
	if typeof(aimDir) ~= "Vector3" or aimDir.Magnitude <= 1e-6 then
		return
	end
	Network.fireServer("SubmitCombatInput", kind, aimDir, style.targetId, style.charge)
	notify(kind)
end

-- The only non-actionable states the client can know for itself. Anything else
-- (cooldowns, windups) is the server's business and is not guessed at here.
local function actionable(): boolean
	local character = Players.LocalPlayer.Character
	if character == nil or character:GetAttribute("CombatAlive") == false then
		return false
	end
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	return matchState ~= nil and matchState:GetAttribute("phase") == "Active"
end

-- Actionable input is sent immediately, so no device pays a frame of latency
-- for the buffer existing. Only input that provably cannot fire yet waits, and
-- only for a short window; inputs that land a hair early otherwise feel dropped.
--
-- This lives on the game side deliberately: it is a weapon-cooldown concern,
-- and PlayerModule has no business knowing when a throw is legal.
local function submit(kind: string, style: Style)
	if actionable() or not MobileInput.Buffer.Enabled then
		send(kind, style)
		return
	end
	InputBuffer.push(buffer, kind, os.clock())
	pendingStyle = style
end

local function flush()
	if not MobileInput.Buffer.Enabled or not actionable() then
		return
	end
	local action = InputBuffer.take(buffer, os.clock(), MobileInput.Buffer.WindowSeconds)
	if action == nil then
		return
	end
	local style = pendingStyle or {}
	pendingStyle = nil
	send(action, style)
end

-- Combat intents arrive already classified by PlayerModule: it decided whether
-- a press was a tap, a hold, a look or a flick, on whichever device the player
-- is using. This module no longer watches input at all -- it turns an intent
-- into a server request and keeps the local visual state in step.
--
-- A bottom swipe and a middle tap both mean "normal throw", which is the whole
-- point of the second gesture: an easier way to do the same thing, not another
-- thing to learn.
local function onIntent(intent: string)
	if intent == "NormalThrow" then
		local kind = intentForTap()
		if CombatState.canStartThrow() then
			CombatState.onThrow(AimDirector.currentAim())
		elseif CombatState.canThrowBall() then
			CombatState.onBlocked()
		end
		submit(kind, {})
	elseif intent == "BeginCharge" then
		-- Only a held ball can be charged. With the hammer out there is nothing
		-- to build, so the hold swings immediately rather than entering a charge
		-- that ReleaseCharge would later discard -- which is why holding longer
		-- than the charge threshold used to do nothing at all.
		if CombatState.canStartThrow() then
			CombatState.beginCharge(os.clock())
		else
			if CombatState.canThrowBall() then
				CombatState.onBlocked()
			end
			submit("Throw", {})
		end
	elseif intent == "ReleaseCharge" then
		if not CombatState.canThrowBall() then
			-- The swing already went out when the charge began.
			CombatState.endCharge()
			return
		end
		-- Read before advancing the state machine, which resets the charge that
		-- the style is built from.
		local style: Style = { charge = CombatState.currentCharge() }
		CombatState.onThrow(AimDirector.currentAim())
		submit("Throw", style)
	elseif intent == "CancelCharge" then
		CombatState.cancelCharge()
	elseif intent == "HammerAttack" then
		submit("Throw", {})
	elseif intent == "EquipHammer" then
		equip("Hammer")
	elseif intent == "EquipDodgeball" then
		equip("Dodgeball")
	end
end

function CombatInputSender.start()
	if started then
		return
	end
	started = true

	intentDisconnect = Combat.onIntent(onIntent)
	heartbeat = RunService.Heartbeat:Connect(flush)
end

function CombatInputSender.destroy()
	if intentDisconnect then
		intentDisconnect()
		intentDisconnect = nil
	end
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(listeners)
	pendingStyle = nil
	buffer = InputBuffer.new()
	started = false
end

return CombatInputSender
