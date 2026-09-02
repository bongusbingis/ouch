-- Name: CombatInputSender.luau
-- Author: Jack C.
-- Description: Turns local combat intents (throw, charge, catch, hammer swing, weapon equip) into server submissions over the combat remotes, buffering inputs that arrive while an action is not yet legal.
-- Created: 2026-08-18

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
	if CombatState.canThrowBall() then
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
	Network.fireServer("SubmitCombatInput", kind, aimDir, style.targetId, style.charge)
	notify(kind)
end

local function actionable(): boolean
	local character = Players.LocalPlayer.Character
	if character == nil or character:GetAttribute("CombatAlive") == false then
		return false
	end
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	return matchState ~= nil and matchState:GetAttribute("phase") == "Active"
end

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
			CombatState.endCharge()
			return
		end
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
