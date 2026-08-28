-- Name: ThrowUXClient.luau
-- Author: Jack C.
-- Description: Derives the throw HUD state from gestures, charge progress, and cooldowns, including the first-time onboarding prompt, and publishes it for the combat HUD.
-- Created: 2026-08-22

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local Config = ReplicatedStorage:WaitForChild("Config")
local CombatConfig = require(Config:WaitForChild("Combat"))
local ThrowUX = require(Config:WaitForChild("ThrowUX"))
local ThrowUXViewModel = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Models"):WaitForChild("ThrowUXViewModel")
)
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimDirector = require(script.Parent.Parent.Input.AimDirector)
local CombatState = require(script.Parent.Parent.Presentation.CombatState)
local CombatFeedback = require(script.Parent.Parent.Presentation.CombatFeedback)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local ThrowUXClient = {}

export type Gesture = {
	kind: string,
	origin: Vector2?,
	position: Vector2?,
	progress: number,
	visible: boolean,
}

export type Snapshot = {
	active: boolean,
	state: ThrowUXViewModel.State,
	chargeAlpha: number,
	cooldownAlpha: number,
	targetConfidence: number,
	inputType: string,
	gesture: Gesture,
	releaseCharge: number,
	releaseRevision: number,
	cancelRevision: number,
	blockedRevision: number,
	readyRevision: number,
	onboardingVisible: boolean,
	debugEnabled: boolean,
}

local EMPTY_GESTURE: Gesture = { kind = "None", origin = nil, position = nil, progress = 0, visible = false }
local snapshot: Snapshot = {
	active = false,
	state = "Idle",
	chargeAlpha = 0,
	cooldownAlpha = 0,
	targetConfidence = 0,
	inputType = "Mouse",
	gesture = EMPTY_GESTURE,
	releaseCharge = 0,
	releaseRevision = 0,
	cancelRevision = 0,
	blockedRevision = 0,
	readyRevision = 0,
	onboardingVisible = false,
	debugEnabled = ThrowUX.Debug.Enabled,
}
local listeners: { (Snapshot) -> () } = {}
local started = false
local heartbeat: RBXScriptConnection? = nil
local gestureCleanup: (() -> ())? = nil
local currentGesture: Gesture = EMPTY_GESTURE
local gestureExpiresAt = 0
local cancelUntil = 0
local releaseUntil = 0
local accumulated = 0
local lastReleaseRevision = 0
local lastCancelRevision = 0
local lastBlockedRevision = 0
local lastReadyRevision = 0
local wasFullCharge = false
local sessionStartedAt = os.clock()
local onboardingShows = 0
local swipeSuccesses = 0
local learnRequestSent = false
local onboardingWasVisible = false

local function publish(nextSnapshot: Snapshot)
	if
		snapshot.active == nextSnapshot.active
		and snapshot.state == nextSnapshot.state
		and snapshot.chargeAlpha == nextSnapshot.chargeAlpha
		and snapshot.cooldownAlpha == nextSnapshot.cooldownAlpha
		and snapshot.targetConfidence == nextSnapshot.targetConfidence
		and snapshot.inputType == nextSnapshot.inputType
		and snapshot.gesture == nextSnapshot.gesture
		and snapshot.releaseRevision == nextSnapshot.releaseRevision
		and snapshot.cancelRevision == nextSnapshot.cancelRevision
		and snapshot.blockedRevision == nextSnapshot.blockedRevision
		and snapshot.readyRevision == nextSnapshot.readyRevision
		and snapshot.onboardingVisible == nextSnapshot.onboardingVisible
		and snapshot.debugEnabled == nextSnapshot.debugEnabled
	then
		return
	end
	snapshot = nextSnapshot
	for _, listener in listeners do
		local ok, err = pcall(listener, nextSnapshot)
		if not ok then
			warn(`[ThrowUXClient] listener error: {err}`)
		end
	end
end

local function onGesture(event)
	local now = os.clock()
	local visible = event.kind == "Pending"
		or event.kind == "SwipeCandidate"
		or event.kind == "SwipeRecognized"
		or event.kind == "TapRecognized"
	currentGesture = {
		kind = event.kind,
		origin = event.origin,
		position = event.position,
		progress = event.progress,
		visible = visible,
	}
	if event.kind == "SwipeRecognized" then
		swipeSuccesses += 1
		if
			swipeSuccesses >= ThrowUX.Onboarding.SuccessesToDismiss
			and Players.LocalPlayer:GetAttribute("SwipeThrowLearned") ~= true
			and not learnRequestSent
		then
			learnRequestSent = true
			Network.fireServer("MarkSwipeThrowLearned")
		end
		gestureExpiresAt = now + ThrowUX.Swipe.RecognizedHoldSeconds
		CombatFeedback.play("Swipe")
	elseif event.kind == "TapRecognized" then
		gestureExpiresAt = now + ThrowUX.Swipe.RecognizedHoldSeconds
	elseif event.kind == "ChargeStarted" then
		CombatFeedback.play("ChargeStart")
	elseif event.kind == "Cancelled" then
		cancelUntil = now + 0.16
		currentGesture = EMPTY_GESTURE
	elseif event.kind == "Camera" or event.kind == "Ended" or event.kind == "ChargeReleased" then
		currentGesture = EMPTY_GESTURE
	end
end

-- Whoever else is on screen decides when this hint is welcome; the module still
-- decides everything else about it. Training uses this to hold the swipe tip
-- back until the throw lesson has already been passed.
local hintGate: (() -> boolean)? = nil

function ThrowUXClient.setHintGate(gate: (() -> boolean)?)
	hintGate = gate
end

local function hintAllowed(): boolean
	local gate = hintGate
	if gate == nil then
		return true
	end
	local ok, allowed = pcall(gate)
	return ok and allowed == true
end

local function onboardingVisible(now: number, inputType: string, ready: boolean): boolean
	if
		not ThrowUX.Onboarding.Enabled
		or inputType ~= "Touch"
		or not ready
		or not hintAllowed()
		or Players.LocalPlayer:GetAttribute("SwipeThrowLearned") == true
		or swipeSuccesses >= ThrowUX.Onboarding.SuccessesToDismiss
		or (onboardingShows >= ThrowUX.Onboarding.MaxShowsPerSession and not onboardingWasVisible)
	then
		return false
	end
	local elapsed = now - sessionStartedAt - ThrowUX.Onboarding.DelaySeconds
	if elapsed < 0 then
		return false
	end
	local cycle = ThrowUX.Onboarding.VisibleSeconds + 5
	return elapsed % cycle < ThrowUX.Onboarding.VisibleSeconds
end

local function update(dt: number)
	accumulated += dt
	if accumulated < 1 / ThrowUX.UpdateHz then
		return
	end
	accumulated %= 1 / ThrowUX.UpdateHz
	local now = os.clock()
	if gestureExpiresAt > 0 and now >= gestureExpiresAt then
		currentGesture = EMPTY_GESTURE
		gestureExpiresAt = 0
	end

	local combat = CombatState.getSnapshot()
	if combat.releaseRevision ~= lastReleaseRevision then
		lastReleaseRevision = combat.releaseRevision
		releaseUntil = now + 0.18
		CombatFeedback.play(if combat.releaseCharge >= 0.8 then "ChargedRelease" else "NormalRelease")
	end
	if combat.cancelRevision ~= lastCancelRevision then
		lastCancelRevision = combat.cancelRevision
		cancelUntil = now + 0.16
	end
	if combat.blockedRevision ~= lastBlockedRevision then
		lastBlockedRevision = combat.blockedRevision
		cancelUntil = now + 0.12
		CombatFeedback.play("Blocked")
	end
	if combat.readyRevision ~= lastReadyRevision then
		lastReadyRevision = combat.readyRevision
		if combat.readyRevision > 1 then
			CombatFeedback.play("CooldownReady")
		end
	end
	local fullCharge = combat.state == "Charging" and combat.chargeAlpha >= 0.995
	CombatFeedback.setCharge(if combat.state == "Charging" then combat.chargeAlpha else 0)
	if fullCharge and not wasFullCharge then
		CombatFeedback.play("FullCharge")
	end
	wasFullCharge = fullCharge

	local inputType = AimDirector.deviceClass()
	local active = Combat.isActive()
	local showOnboarding = onboardingVisible(now, inputType, combat.ready and active)
	if showOnboarding and not onboardingWasVisible then
		onboardingShows += 1
	end
	onboardingWasVisible = showOnboarding
	local pending = currentGesture.kind == "Pending" or currentGesture.kind == "SwipeCandidate"
	local targetConfidence = math.floor(AimDirector.currentConfidence() * 20 + 0.5) / 20
	publish({
		active = active,
		state = ThrowUXViewModel.state({
			weapon = combat.weapon,
			holdsBall = combat.holdsBall,
			combatState = combat.state,
			chargeAlpha = combat.chargeAlpha,
			throwCooldown = combat.throwCooldown,
			ready = combat.ready,
			pendingInput = pending,
			releaseActive = now < releaseUntil,
			cancelActive = now < cancelUntil,
		}),
		chargeAlpha = combat.chargeAlpha,
		cooldownAlpha = ThrowUXViewModel.cooldownAlpha(combat.throwCooldown, CombatConfig.Dodgeball.ThrowCooldown),
		targetConfidence = targetConfidence,
		inputType = inputType,
		gesture = currentGesture,
		releaseCharge = combat.releaseCharge,
		releaseRevision = combat.releaseRevision,
		cancelRevision = combat.cancelRevision,
		blockedRevision = combat.blockedRevision,
		readyRevision = combat.readyRevision,
		onboardingVisible = showOnboarding,
		debugEnabled = ThrowUX.Debug.Enabled,
	})
end

function ThrowUXClient.getSnapshot(): Snapshot
	return snapshot
end

function ThrowUXClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function ThrowUXClient.start()
	if started then
		return
	end
	started = true
	sessionStartedAt = os.clock()
	learnRequestSent = Players.LocalPlayer:GetAttribute("SwipeThrowLearned") == true
	gestureCleanup = Combat.onGesture(onGesture)
	heartbeat = RunService.Heartbeat:Connect(update)
	update(1 / ThrowUX.UpdateHz)
end

function ThrowUXClient.destroy()
	if gestureCleanup then
		gestureCleanup()
		gestureCleanup = nil
	end
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	CombatFeedback.destroy()
	table.clear(listeners)
	currentGesture = EMPTY_GESTURE
	started = false
end

return ThrowUXClient
