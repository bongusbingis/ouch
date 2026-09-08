-- Description: Turns local combat intents (throw, charge, catch, hammer swing, weapon equip) into server submissions over the combat remotes, buffering inputs that arrive while an action is not yet legal.

--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MobileInput =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("MobileInput"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local InputBuffer = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input"):WaitForChild("InputBuffer")
)
local CombatActionRules = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Input")
		:WaitForChild("CombatActionRules")
)
local AimDirector = require(script.Parent.AimDirector)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local CombatState = require(script.Parent.Parent.Presentation.CombatState)

local CombatInputSender = {}

local started = false
local listeners: { (string) -> () } = {}
local intentDisconnect: (() -> ())? = nil
local heartbeat: RBXScriptConnection? = nil
local buffer = InputBuffer.new()
type Style = { targetId: string?, charge: number? }

local pendingStyle: Style? = nil
local pendingWeapon: string? = nil
local pendingCharacter: Model? = nil

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

local function intentForTap(): string
	if CombatState.holdsBall() then
		return "Throw"
	end
	return if ballIncoming() then "Catch" else "Throw"
end

local function equip(weapon: string)
	Network.fireServer("SubmitWeaponEquip", weapon)
end

local function send(kind: string, style: Style)
	local aimDir = AimDirector.currentAim()
	if typeof(aimDir) ~= "Vector3" or aimDir.Magnitude <= 1e-6 then
		return
	end
	if kind == "Throw" and CombatState.canThrowBall() then
		CombatState.onThrow(aimDir, style.charge)
	end
	Network.fireServer("SubmitCombatInput", kind, aimDir, style.targetId, style.charge)
	notify(kind)
end

local function actionStatus(kind: string): string
	local player = Players.LocalPlayer
	local character = player.Character
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	local snapshot = CombatState.getSnapshot()
	return CombatActionRules.status(kind, {
		enabled = Combat.isInputEnabled(),
		active = matchState ~= nil and matchState:GetAttribute("phase") == "Active",
		alive = character ~= nil and character:GetAttribute("CombatAlive") ~= false,
		eligible = player:GetAttribute("ArenaRoundEligible") ~= false,
		weapon = snapshot.weapon,
		holdsBall = snapshot.holdsBall,
		throwCooldown = snapshot.throwCooldown,
		hammerCooldown = snapshot.hammerCooldown,
		catchCooldown = if character then (character:GetAttribute("dbCc") :: number?) or 0 else 0,
	})
end

local function clearBuffer()
	InputBuffer.clear(buffer)
	pendingStyle = nil
	pendingWeapon = nil
	pendingCharacter = nil
end

local function submit(kind: string, style: Style)
	local status = actionStatus(kind)
	if status == "Ready" then
		clearBuffer()
		send(kind, style)
	elseif status == "Cooldown" and MobileInput.Buffer.Enabled then
		InputBuffer.push(buffer, kind, os.clock())
		pendingStyle = style
		pendingWeapon = CombatState.getSnapshot().weapon
		pendingCharacter = Players.LocalPlayer.Character
	else
		clearBuffer()
	end
end

local function flush()
	local action = InputBuffer.peek(buffer, os.clock(), MobileInput.Buffer.WindowSeconds)
	if
		action == nil
		or not MobileInput.Buffer.Enabled
		or pendingWeapon ~= CombatState.getSnapshot().weapon
		or pendingCharacter ~= Players.LocalPlayer.Character
	then
		clearBuffer()
		return
	end
	local status = actionStatus(action)
	if status == "Unavailable" then
		clearBuffer()
	elseif status == "Ready" then
		local style = pendingStyle or {}
		clearBuffer()
		send(action, style)
	end
end

local function onIntent(intent: string)
	if intent == "NormalThrow" then
		local kind = intentForTap()
		if actionStatus(kind) ~= "Ready" and CombatState.canThrowBall() then
			CombatState.onBlocked()
		end
		submit(kind, {})
	elseif intent == "BeginCharge" then
		if CombatState.canStartThrow() and actionStatus("Throw") == "Ready" then
			clearBuffer()
			CombatState.beginCharge(os.clock())
			Network.fireServer("SubmitCombatInput", "BeginCharge", Vector3.zAxis)
		else
			if CombatState.canThrowBall() then
				CombatState.onBlocked()
			end
			submit("Throw", {})
		end
	elseif intent == "ReleaseCharge" then
		if not CombatState.canThrowBall() then
			CombatState.endCharge()
			return
		end
		local style: Style = { charge = CombatState.currentCharge() }
		CombatState.endCharge()
		submit("Throw", style)
	elseif intent == "CancelCharge" then
		clearBuffer()
		CombatState.cancelCharge()
		Network.fireServer("SubmitCombatInput", "CancelCharge", Vector3.zAxis)
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
	clearBuffer()
	buffer = InputBuffer.new()
	started = false
end

return CombatInputSender
