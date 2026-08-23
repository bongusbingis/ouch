--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ThrowPose = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThrowPose"))
local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local SimStateCodec = require(Adapters:WaitForChild("SimStateCodec"))

-- The local player's visual combat state, and the only place charge is measured.
--
-- Several systems need to know what this player is doing right now: the pose
-- layer, the arm IK, the animation layer, and the input sender that has to
-- attach a charge value to the throw it sends. Before this existed each of them
-- worked it out again from the raw button, which meant three slightly different
-- answers and no way to keep them in step.
--
-- This owns none of the input detection. CombatInputSender is the single edge
-- detector and pushes presses in here; this turns them into a state and a charge
-- that everyone else reads. Nothing here decides whether an action is legal --
-- that is the server's job, and this state is purely what the local player's
-- character should look like.

local CombatState = {}

local HELD_PHASE = 0

export type State = "Idle" | "BallEquipped" | "Aiming" | "Charging" | "Throwing" | "FollowThrough" | "Recovering"

export type Snapshot = {
	-- The equipped weapon, read from the server's projection rather than guessed
	-- from ball possession. The sim owns the choice; this is a mirror of it.
	weapon: string,
	-- Whether a dodgeball is actually in hand. Distinct from weapon: a player can
	-- have the dodgeball equipped with nothing to throw, and can hold a ball while
	-- swinging the hammer.
	holdsBall: boolean,
	state: State,
	-- 0-1 hold progress. Non-zero only while Charging.
	chargeAlpha: number,
	throwCooldown: number,
	ready: boolean,
	releaseCharge: number,
	releaseRevision: number,
	cancelRevision: number,
	blockedRevision: number,
	readyRevision: number,
}

local started = false
local ballsFolder: Folder? = nil
local listeners: { (Snapshot) -> () } = {}

local snapshot: Snapshot = {
	weapon = "Hammer",
	holdsBall = false,
	state = "Idle",
	chargeAlpha = 0,
	throwCooldown = 0,
	ready = false,
	releaseCharge = 0,
	releaseRevision = 0,
	cancelRevision = 0,
	blockedRevision = 0,
	readyRevision = 0,
}
local pressedAt: number? = nil
-- Counts down the post-release states. Nil whenever the state is input-driven.
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
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	return matchState == nil or matchState:GetAttribute("phase") == "Active"
end

local function enter(state: State, duration: number?)
	snapshot.state = state
	stateExpiresAt = if duration then os.clock() + duration else nil
end

-- Recomputes the state from whatever is currently true. Called every frame
-- rather than only on transitions: a ball can be lost to a catch or a death at
-- any moment, and a pose left in Charging after that is exactly the kind of
-- stuck visual state that outlives the thing that caused it.
local function evaluate()
	local now = os.clock()
	local previousState = snapshot.state
	local previousCharge = snapshot.chargeAlpha
	local previousCooldown = snapshot.throwCooldown
	local previousReady = snapshot.ready

	snapshot.holdsBall = holdsBall()
	-- The character carries it because that is where the sim encodes it. Absent
	-- until the first server step of a fresh character, which is exactly when the
	-- default applies anyway.
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
		-- Post-release states run in a fixed order and then hand back to the
		-- input-driven states.
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
		-- Nothing to wind up: either the hammer is out, which swings from its
		-- authored clip and wants this layer out of the way, or the ball weapon is
		-- equipped with an empty hand and there is no throw to pose for.
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

	-- One charge clock for every device. PlayerModule decides *that* a charge
	-- began, on whichever device; the ramp from there is a gameplay curve and is
	-- timed here.
	--
	-- The clock starts when the charge begins, so it ramps straight from zero.
	-- It used to run through Gestures.chargeFor, which subtracts the hold
	-- threshold a second time -- charge then stayed at zero for a further 0.25s
	-- and a throw released inside that window sent charge = 0 while the pose was
	-- already showing a wind-up.
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

-- Called by CombatInputSender when a throw press begins. A press that turns out
-- to be a hammer swing never reaches here.
function CombatState.beginCharge(at: number)
	pressedAt = at
	evaluate()
end

-- Called when that press ends without becoming a throw.
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

-- Called at the moment a throw is actually sent. Drives the post-release states
-- so the pose layer can get out of the animation's way.
function CombatState.onThrow()
	snapshot.releaseCharge = snapshot.chargeAlpha
	snapshot.releaseRevision += 1
	pressedAt = nil
	enter("Throwing", ThrowPose.Timing.ThrowingSeconds)
	snapshot.chargeAlpha = 0
	publish()
end

-- Called by the animation layer when the throw clip reaches its Release marker,
-- so the hand-off to the follow-through follows the authored timing instead of a
-- duration guessed here. Harmless when no marker exists: the timer covers it.
function CombatState.onReleaseMarker()
	if snapshot.state ~= "Throwing" then
		return
	end
	enter("FollowThrough", ThrowPose.Timing.FollowThroughSeconds)
	publish()
end

-- The charge behind a throw being sent right now. The input sender reads this
-- rather than measuring the hold itself, so the value that reaches the server is
-- the same one the player watched build.
function CombatState.currentCharge(): number
	return snapshot.chargeAlpha
end

-- Whether a dodgeball throw is possible right now: the ball weapon is out *and*
-- there is a ball in hand. Both halves matter -- charging with an empty hand
-- would build a throw that never happens, and holding a ball while the hammer is
-- equipped must not start one either.
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

	-- Losing the character mid-charge must not leave the pose wound up.
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		pressedAt = nil
		stateExpiresAt = nil
		snapshot.state = "Idle"
		snapshot.chargeAlpha = 0
		publish()
	end)

	RunService.Heartbeat:Connect(evaluate)
end

return CombatState
