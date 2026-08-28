-- Name: CombatState.luau
-- Author: Jack C.
-- Description: Client-side view of the local player's combat state, deriving charge progress and whether a throw or swing is currently legal from replicated sim attributes, and publishing snapshots to the HUD and presentation modules.
-- Created: 2026-08-20

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ThrowPose = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThrowPose"))
local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local CombatSession = require(Adapters:WaitForChild("CombatSession"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local SimStateCodec = require(Adapters:WaitForChild("SimStateCodec"))

local CombatState = {}

local HELD_PHASE = 0

export type State = "Idle" | "BallEquipped" | "Aiming" | "Charging" | "Throwing" | "FollowThrough" | "Recovering"

export type Snapshot = {
	weapon: string,
	holdsBall: boolean,
	state: State,
	chargeAlpha: number,
	throwCooldown: number,
	ready: boolean,
	releaseCharge: number,
	releaseAim: Vector3?,
	releaseRevision: number,
	cancelRevision: number,
	blockedRevision: number,
	readyRevision: number,
}

local started = false
local ballsFolder: Folder? = nil
local listeners: { (Snapshot) -> () } = {}
local characterRemovingConnection: RBXScriptConnection? = nil
local heartbeat: RBXScriptConnection? = nil

local snapshot: Snapshot = {
	weapon = "Hammer",
	holdsBall = false,
	state = "Idle",
	chargeAlpha = 0,
	throwCooldown = 0,
	ready = false,
	releaseCharge = 0,
	releaseAim = nil,
	releaseRevision = 0,
	cancelRevision = 0,
	blockedRevision = 0,
	readyRevision = 0,
}
local pressedAt: number? = nil
local stateExpiresAt: number? = nil

local function publish()
	for _, listener in listeners do
		local ok, err = pcall(listener, snapshot)
		if not ok then
			warn("[CombatState] listener error: " .. tostring(err))
		end
	end
end

local function holdsBall(): boolean
	local folder = ballsFolder
	if folder == nil then
		return false
	end
	local localId = PlayerIds.toId(Players.LocalPlayer)
	for _, ball in folder:GetChildren() do
		if ball:GetAttribute("hb") == localId and ball:GetAttribute("ph") == HELD_PHASE then
			return true
		end
	end
	return false
end

local function matchIsActive(): boolean
	return CombatSession.isLive()
end

local function enter(state: State, duration: number?)
	snapshot.state = state
	stateExpiresAt = if duration then os.clock() + duration else nil
end

local function evaluate()
	local now = os.clock()
	local previousState = snapshot.state
	local previousCharge = snapshot.chargeAlpha
	local previousCooldown = snapshot.throwCooldown
	local previousReady = snapshot.ready

	snapshot.holdsBall = holdsBall()
	local character = Players.LocalPlayer.Character
	local equipped = if character then character:GetAttribute(SimStateCodec.EquippedAttribute) :: string? else nil
	snapshot.weapon = equipped or "Hammer"
	snapshot.throwCooldown = if character then math.max((character:GetAttribute("dbTc") :: number?) or 0, 0) else 0
	snapshot.ready = CombatState.canStartThrow()
	if snapshot.ready and not previousReady then
		snapshot.readyRevision += 1
	end

	local expiry = stateExpiresAt
	if expiry ~= nil then
		if now < expiry then
			if previousCooldown ~= snapshot.throwCooldown or previousReady ~= snapshot.ready then
				publish()
			end
			return
		end
		local timing = ThrowPose.Timing
		if snapshot.state == "Throwing" then
			enter("FollowThrough", timing.FollowThroughSeconds)
		elseif snapshot.state == "FollowThrough" then
			enter("Recovering", timing.RecoveringSeconds)
		else
			enter("Idle")
		end
		publish()
		return
	end

	if not CombatState.canThrowBall() then
		snapshot.chargeAlpha = 0
		snapshot.state = "Idle"
		if
			previousState ~= "Idle"
			or previousCharge ~= 0
			or previousCooldown ~= snapshot.throwCooldown
			or previousReady ~= snapshot.ready
		then
			publish()
		end
		return
	end

	local held = pressedAt
	if held ~= nil then
		snapshot.state = "Charging"
		local full = math.max(MobileInput.Gestures.ChargeFullSeconds, 1e-3)
		snapshot.chargeAlpha = math.clamp((now - held) / full, 0, 1)
	else
		snapshot.state = if matchIsActive() then "Aiming" else "BallEquipped"
		snapshot.chargeAlpha = 0
	end

	if
		previousState ~= snapshot.state
		or previousCharge ~= snapshot.chargeAlpha
		or previousCooldown ~= snapshot.throwCooldown
		or previousReady ~= snapshot.ready
	then
		publish()
	end
end

function CombatState.beginCharge(at: number)
	pressedAt = at
	evaluate()
end

function CombatState.endCharge()
	pressedAt = nil
	evaluate()
end

function CombatState.cancelCharge()
	local wasCharging = pressedAt ~= nil or snapshot.state == "Charging"
	pressedAt = nil
	if wasCharging then
		snapshot.cancelRevision += 1
	end
	evaluate()
end

function CombatState.onThrow(aim: Vector3?)
	snapshot.releaseAim = if typeof(aim) == "Vector3" and aim.Magnitude > 1e-6 then aim.Unit else nil
	snapshot.releaseCharge = snapshot.chargeAlpha
	snapshot.releaseRevision += 1
	pressedAt = nil
	enter("Throwing", ThrowPose.Timing.ThrowingSeconds)
	snapshot.chargeAlpha = 0
	publish()
end

function CombatState.onReleaseMarker()
	if snapshot.state ~= "Throwing" then
		return
	end
	enter("FollowThrough", ThrowPose.Timing.FollowThroughSeconds)
	publish()
end

function CombatState.currentCharge(): number
	return snapshot.chargeAlpha
end

function CombatState.canThrowBall(): boolean
	return snapshot.weapon == "Dodgeball" and snapshot.holdsBall
end

function CombatState.canStartThrow(): boolean
	return CombatState.canThrowBall() and snapshot.throwCooldown <= 0 and matchIsActive()
end

function CombatState.onBlocked()
	snapshot.blockedRevision += 1
	publish()
end

function CombatState.holdsBall(): boolean
	return snapshot.holdsBall
end

function CombatState.getSnapshot(): Snapshot
	return snapshot
end

function CombatState.subscribe(listener: (Snapshot) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function CombatState.start()
	if started then
		return
	end
	started = true

	local resolved = Workspace:WaitForChild("Balls")
	assert(resolved:IsA("Folder"), "[CombatState] Workspace.Balls must be a Folder")
	ballsFolder = resolved

	characterRemovingConnection = Players.LocalPlayer.CharacterRemoving:Connect(function()
		pressedAt = nil
		stateExpiresAt = nil
		snapshot.state = "Idle"
		snapshot.chargeAlpha = 0
		publish()
	end)

	heartbeat = RunService.Heartbeat:Connect(evaluate)
end

function CombatState.destroy()
	if characterRemovingConnection then
		characterRemovingConnection:Disconnect()
		characterRemovingConnection = nil
	end
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	ballsFolder = nil
	pressedAt = nil
	stateExpiresAt = nil
	table.clear(listeners)
	started = false
end

return CombatState
