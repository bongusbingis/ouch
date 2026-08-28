-- Name: OnboardingService.luau
-- Author: Jack C.
-- Description: The single owner of the first-session onboarding: resolves eligibility from the profile, runs one training session per eligible player against the real combat simulation, advances the step machine from sim events, persists checkpoints, reports the funnel, and hands the player to the normal lobby however the session ends.
-- Created: 2026-08-27

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnalyticsConfig = require(Config:WaitForChild("Analytics"))
local Combat = require(Config:WaitForChild("Combat"))
local OnboardingConfig = require(Config:WaitForChild("Onboarding"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local SharedGame = Shared:WaitForChild("Game")
local Adapters = SharedGame:WaitForChild("Adapters")
local CombatSession = require(Adapters:WaitForChild("CombatSession"))
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))
local Onboarding = SharedGame:WaitForChild("Onboarding")
local OnboardingAnalytics = require(Onboarding:WaitForChild("OnboardingAnalytics"))
local OnboardingLayout = require(Onboarding:WaitForChild("OnboardingLayout"))
local OnboardingState = require(Onboarding:WaitForChild("OnboardingState"))
local OnboardingSteps = require(Onboarding:WaitForChild("OnboardingSteps"))

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local AnalyticsService = require(Modules:WaitForChild("AnalyticsService"))
local BallService = require(Modules:WaitForChild("BallService"))
local ConfigLiveService = require(Modules:WaitForChild("ConfigLiveService"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local OnboardingWorld = require(script.Parent:WaitForChild("OnboardingWorld"))
local PracticeBots = require(script.Parent:WaitForChild("PracticeBots"))
local TrainingDummies = require(script.Parent:WaitForChild("TrainingDummies"))

local OnboardingService = {}

-- Routing is a server decision projected as one attribute. The client renders
-- what it is told; it never re-derives eligibility from profile data.
local ROUTE_ATTRIBUTE = "OnboardingRoute"
local STEP_ATTRIBUTE = "OnboardingStep"
local HINT_ATTRIBUTE = "OnboardingHint"

export type EndReason = "Completed" | "Skipped" | "PartyMatch" | "Left" | "Timeout" | "Error"

type Session = {
	player: Player,
	slot: number,
	step: OnboardingSteps.Step,
	resumed: boolean,
	startedAt: number,
	stepStartedAt: number,
	lastAttemptAt: number,
	attempts: number,
	escalated: boolean,
	hint: string,
	-- The dummy the current step is about; practice keeps its bots separately.
	dummyId: string?,
	practiceKnockouts: number,
	practiceStartedAt: number?,
	advanceAt: number?,
	celebrateAt: number?,
	ballCheckedAt: number,
	returnCFrame: CFrame?,
	partyPrompted: boolean,
	ending: boolean,
}

local sessions: { [Player]: Session } = {}
local slots: { [number]: Player } = {}
local chargeByProjectile: { [string]: number } = {}
local simDedup = EventDedup.new(512)
local partyPhases: { [Player]: string } = {}
local started = false

-- The layout module is pure and speaks the native vector type; the engine side
-- converts once, here.
local function toVector3(value: vector): Vector3
	return Vector3.new(value.x, value.y, value.z)
end

-- Sim events carry positions and directions as native vectors, but a few are
-- already Vector3 by the time a listener sees them; both are accepted rather
-- than assumed.
local function worldVector(value: any): Vector3?
	if typeof(value) == "Vector3" then
		return value
	elseif typeof(value) == "vector" then
		return toVector3(value)
	end
	return nil
end

local function sessionForId(playerId: string?): Session?
	if playerId == nil then
		return nil
	end
	local player = PlayerIds.fromId(playerId)
	return if player then sessions[player] else nil
end

local function allocateSlot(player: Player): number
	local slot = 1
	while slots[slot] ~= nil do
		slot += 1
	end
	slots[slot] = player
	return slot
end

local function releaseSlot(slot: number)
	slots[slot] = nil
end

local function fire(player: Player, kind: string, payload: { [string]: any }?)
	Network.fire("OnboardingEvent", player, kind, payload or {})
end

local function deviceClass(player: Player): string
	return OnboardingAnalytics.deviceClass(player:GetAttribute("DeviceClass"))
end

local function logStepEvent(session: Session, eventName: string, value: number)
	AnalyticsService.logCustomEvent(
		session.player,
		eventName,
		OnboardingAnalytics.duration(value),
		OnboardingAnalytics.stepFields({
			stepId = session.step.Id,
			durationSeconds = value,
			attempts = session.attempts,
			escalated = session.escalated,
			deviceClass = deviceClass(session.player),
			resumed = session.resumed,
		})
	)
end

local function logFunnel(session: Session, key: string)
	local funnelStep = OnboardingAnalytics.funnelStep(key)
	if funnelStep == nil then
		return
	end
	AnalyticsService.logFunnelStep(
		session.player,
		AnalyticsConfig.Funnels.Onboarding,
		funnelStep.step,
		funnelStep.name,
		{ deviceClass = deviceClass(session.player), resumed = session.resumed }
	)
end

local function setHint(session: Session, hint: string)
	if session.hint == hint then
		return
	end
	session.hint = hint
	session.player:SetAttribute(HINT_ATTRIBUTE, hint)
end

-- Every world consequence of leaving a step lives here, so no two steps can
-- disagree about what tearing one down means.
local function clearStepWorld(session: Session)
	if session.dummyId then
		TrainingDummies.despawn(session.dummyId)
		session.dummyId = nil
	end
	PracticeBots.clear(session.slot)
	OnboardingWorld.moveSpotlight(session.slot, nil)
end

local function grantBall(session: Session)
	local player = session.player
	if BallService.hasHeldBall(player) then
		return
	end
	BallService.grantHeldBall(player)
end

local function takeBall(session: Session)
	BallService.clearOwned(PlayerIds.toId(session.player))
end

local function placeCharacter(session: Session)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	local frame = OnboardingLayout.frame(session.slot)
	local spawn = toVector3(frame.spawn)
	-- The rings sit far from the lobby proper and this place streams, so the
	-- region is requested before the player is put in it.
	pcall(function()
		session.player:RequestStreamingAround(spawn)
	end)
	character:PivotTo(CFrame.lookAt(spawn, toVector3(frame.facing)))
	root.AssemblyLinearVelocity = Vector3.zero
	-- Invulnerability is what keeps a 45-second onboarding free of a death and
	-- respawn interruption; the sim already honours it for every weapon.
	character:SetAttribute("minv", true)
	character:SetAttribute("CombatAlive", true)
	return true
end

local function enterStep(session: Session, step: OnboardingSteps.Step)
	clearStepWorld(session)
	session.step = step
	session.stepStartedAt = os.clock()
	session.lastAttemptAt = os.clock()
	session.ballCheckedAt = os.clock()
	session.attempts = 0
	session.escalated = false
	OnboardingWorld.emphasizeTarget(session.slot, false)
	session.advanceAt = nil
	session.practiceKnockouts = 0
	session.practiceStartedAt = nil
	setHint(session, "")
	session.player:SetAttribute(STEP_ATTRIBUTE, step.Id)

	local frame = OnboardingLayout.frame(session.slot)
	if step.Id == "Practice" then
		takeBall(session)
		grantBall(session)
		session.practiceStartedAt = os.clock()
		PracticeBots.spawn(session.slot, OnboardingConfig.Training.PracticeBotCount, toVector3(frame.spawn))
	else
		local target = OnboardingLayout.targetPosition(session.slot, step.Id)
		if target then
			local dummy = TrainingDummies.spawn(step.Id, toVector3(target), toVector3(frame.spawn))
			session.dummyId = dummy.id
			OnboardingWorld.moveSpotlight(session.slot, toVector3(target))
		end
		if step.Weapon == "Hammer" then
			-- Both halves matter: without the ball there is nothing to throw, and
			-- without the explicit equip a Throw press still routes to the ball
			-- kit and does nothing. Stating it keeps the lesson working on every
			-- device without a weapon-select control.
			takeBall(session)
			ServerAuthAdapter.equipWeapon(session.player, "Hammer")
		else
			grantBall(session)
		end
	end

	fire(session.player, "StepStarted", { stepId = step.Id, index = step.Index })
	logFunnel(session, step.Id)
	AnalyticsService.logCustomEvent(
		session.player,
		AnalyticsConfig.CustomEvents.OnboardingStepStarted,
		step.Index,
		OnboardingAnalytics.stepFields({
			stepId = step.Id,
			durationSeconds = 0,
			attempts = 0,
			escalated = false,
			deviceClass = deviceClass(session.player),
			resumed = session.resumed,
		})
	)
end

local function persistStep(session: Session, stepId: string): boolean
	local updated = PlayerData.updateOnboarding(session.player, function(state)
		return OnboardingState.completeStep(state, stepId)
	end)
	local earnedCore = updated ~= nil and updated.Status == "CoreComplete" and stepId == OnboardingSteps.lastCore().Id
	if earnedCore then
		AnalyticsService.logCustomEvent(
			session.player,
			AnalyticsConfig.CustomEvents.OnboardingCoreComplete,
			OnboardingAnalytics.duration(os.clock() - session.startedAt),
			{ deviceClass = deviceClass(session.player), resumed = session.resumed }
		)
	end
	return earnedCore
end

local endSession

local function completeStep(session: Session)
	local step = session.step
	if session.advanceAt ~= nil or session.celebrateAt ~= nil then
		return
	end
	logStepEvent(session, AnalyticsConfig.CustomEvents.OnboardingStepCompleted, os.clock() - session.stepStartedAt)
	local earnedCore = persistStep(session, step.Id)
	fire(session.player, "StepCompleted", { stepId = step.Id, success = step.Success, coreComplete = earnedCore })

	local nextStep = OnboardingSteps.after(step.Id)
	if nextStep == nil then
		session.advanceAt = nil
		session.celebrateAt = os.clock() + OnboardingConfig.Timing.CelebrationSeconds
		clearStepWorld(session)
		local frame = OnboardingLayout.frame(session.slot)
		OnboardingWorld.celebrate(session.slot, toVector3(frame.spawn))
		local portal = OnboardingWorld.openPortal(session.slot)
		fire(session.player, "Celebration", { completed = OnboardingSteps.coreIds(), portal = portal })
		return
	end
	session.advanceAt = os.clock() + OnboardingConfig.Timing.StepAdvanceSeconds
end

local function registerAttempt(session: Session)
	session.attempts += 1
	session.lastAttemptAt = os.clock()
end

local function escalate(session: Session)
	if session.escalated then
		return
	end
	session.escalated = true
	if session.dummyId then
		TrainingDummies.setForgiveness(session.dummyId, OnboardingConfig.Training.EscalatedForgiveness)
	end
	OnboardingWorld.emphasizeTarget(session.slot, true)
	setHint(session, "Escalated")
	fire(session.player, "HintEscalated", { stepId = session.step.Id })
end

local function knockOutTarget(session: Session, targetId: string, direction: Vector3?, at: Vector3?)
	local position = at or TrainingDummies.position(targetId)
	TrainingDummies.knockOut(targetId, direction)
	if position then
		OnboardingWorld.impactRing(session.slot, position)
	end
	fire(session.player, "TargetKnockedOut", { stepId = session.step.Id, position = position })
end

-- Sim events are the only thing that completes a step: the player has to
-- actually land the hit, not merely press the button.
local function onSimEvent(event: { [string]: any })
	local projectileId = event.projectileId
	if event.kind == "BallReleased" and projectileId ~= nil then
		-- How hard the throw was charged is carried on the ball by the codec,
		-- which has already run for this tick when listeners are dispatched.
		local balls = Workspace:FindFirstChild("Balls")
		local instance = balls and balls:FindFirstChild(projectileId)
		chargeByProjectile[projectileId] = if instance then (instance:GetAttribute("rc") :: number?) or 0 else 0
		return
	end
	if (event.kind == "BallSettled" or event.kind == "BallReturned") and projectileId ~= nil then
		chargeByProjectile[projectileId] = nil
		return
	end

	if not simDedup.markSeen(event) then
		return
	end

	if event.kind == "BallWindup" or event.kind == "HammerSwing" then
		local session = sessionForId(event.playerId)
		if session then
			registerAttempt(session)
		end
		return
	end

	if event.kind ~= "Elim" then
		return
	end

	local session = sessionForId(event.sourceId)
	if session == nil or session.ending then
		return
	end
	local targetId = event.targetId
	if targetId == nil or not TrainingDummies.isDummy(targetId) then
		return
	end

	local usedDodgeball = projectileId ~= nil
	local charge = if projectileId then chargeByProjectile[projectileId] or 0 else 0
	if projectileId then
		chargeByProjectile[projectileId] = nil
	end

	local step = session.step
	knockOutTarget(session, targetId, worldVector(event.direction), worldVector(event.position))

	if step.Demands == "DodgeballElim" and usedDodgeball then
		completeStep(session)
	elseif step.Demands == "HammerElim" and not usedDodgeball then
		completeStep(session)
	elseif step.Demands == "ChargedElim" then
		if usedDodgeball and charge >= OnboardingConfig.Training.MinimumChargeAlpha then
			completeStep(session)
		else
			-- A tap throw that happens to reach still knocks the dummy over; the
			-- lesson is not passed until the player actually holds, so the target
			-- comes back and the prompt stays put.
			fire(session.player, "ChargeTooWeak", { stepId = step.Id })
		end
	elseif step.Demands == "Knockouts" then
		session.practiceKnockouts += 1
		fire(session.player, "PracticeProgress", {
			knockouts = session.practiceKnockouts,
			required = OnboardingConfig.Training.PracticeKnockouts,
		})
		if session.practiceKnockouts >= OnboardingConfig.Training.PracticeKnockouts then
			completeStep(session)
		end
	end
end

local function restoreTargets(session: Session)
	local respawn = OnboardingConfig.Timing.DummyRespawnSeconds
	local now = os.clock()
	local dummyId = session.dummyId
	if dummyId ~= nil and TrainingDummies.isKnockedOut(dummyId) then
		local dummy = TrainingDummies.get(dummyId)
		if dummy and dummy.knockedOutAt and now - dummy.knockedOutAt >= respawn then
			TrainingDummies.restore(dummyId)
		end
	end
end

local function stepAssistance(session: Session)
	local timing = OnboardingConfig.Timing
	local idle = os.clock() - session.lastAttemptAt
	if session.attempts >= timing.EscalateAfterAttempts or idle >= timing.EscalatedHintSeconds then
		escalate(session)
	elseif idle >= timing.InactivityHintSeconds and session.hint == "" then
		setHint(session, "Nudge")
		fire(session.player, "HintNudge", { stepId = session.step.Id })
	end
end

-- Missing is never a dead end: if the player has been without a ball for longer
-- than it takes to notice, one is handed straight back.
local function ensureBall(session: Session)
	if session.step.Weapon == "Hammer" then
		return
	end
	local now = os.clock()
	if BallService.hasHeldBall(session.player) then
		session.ballCheckedAt = now
		return
	end
	if now - session.ballCheckedAt >= OnboardingConfig.Timing.BallReturnSeconds then
		session.ballCheckedAt = now
		grantBall(session)
	end
end

local function recoverFalls(session: Session)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	if root.Position.Y < OnboardingLayout.fallHeight(session.slot) then
		placeCharacter(session)
		fire(session.player, "Recovered", { stepId = session.step.Id })
	end
end

local function revealLobby(player: Player, reason: EndReason)
	player:SetAttribute(ROUTE_ATTRIBUTE, "Lobby")
	player:SetAttribute(STEP_ATTRIBUTE, "")
	player:SetAttribute(HINT_ATTRIBUTE, "")
	fire(player, "Reveal", { reason = reason })
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.OnboardingLobbyRevealed, 1, {
		reason = reason,
		deviceClass = deviceClass(player),
	})
end

function endSession(player: Player, reason: EndReason)
	local session = sessions[player]
	if session == nil or session.ending then
		return
	end
	session.ending = true
	sessions[player] = nil

	clearStepWorld(session)
	OnboardingWorld.destroy(session.slot)
	releaseSlot(session.slot)
	takeBall(session)

	local character = player.Character
	if character then
		character:SetAttribute("minv", nil)
		local returnTo = session.returnCFrame
		if returnTo then
			character:PivotTo(returnTo)
		end
	end

	local duration = os.clock() - session.startedAt
	local stored = PlayerData.getOnboarding(player)
	local fields = OnboardingAnalytics.sessionFields({
		stepId = session.step.Id,
		status = if stored then stored.Status else "Unknown",
		durationSeconds = duration,
		deviceClass = deviceClass(player),
		resumed = session.resumed,
		coreComplete = stored ~= nil and OnboardingState.hasCore(stored),
		reason = reason,
	})

	local eventName = AnalyticsConfig.CustomEvents.OnboardingAbandoned
	if reason == "Completed" then
		eventName = AnalyticsConfig.CustomEvents.OnboardingCompleted
		logFunnel(session, "Completed")
	elseif reason == "Skipped" then
		eventName = AnalyticsConfig.CustomEvents.OnboardingSkipped
	end
	AnalyticsService.logCustomEvent(player, eventName, OnboardingAnalytics.duration(duration), fields)

	if player.Parent == Players then
		revealLobby(player, reason)
	end
	CombatSession.forget(player)
	if next(sessions) == nil then
		ConfigLiveService.releaseLatched()
	end
end

local function finishSession(session: Session)
	PlayerData.updateOnboarding(session.player, OnboardingState.complete)
	endSession(session.player, "Completed")
end

local function beginSession(player: Player, voluntary: boolean)
	if sessions[player] ~= nil then
		return
	end
	local loaded = PlayerData.getOnboarding(player)
	if loaded == nil then
		return
	end
	-- Migrate before reading the checkpoint: progress that belongs to an older
	-- onboarding version does not name a step in this one.
	local stored = OnboardingState.migrate(loaded, OnboardingConfig.Version)
	local resumeStep = OnboardingState.resumeStep(stored, OnboardingConfig.Eligibility.ResumeEnabled and not voluntary)
	local resumed = resumeStep.Index > 1
	PlayerData.updateOnboarding(player, function(state)
		local begun = OnboardingState.begin(state, OnboardingConfig.Version)
		return if voluntary then OnboardingState.replay(begun) else begun
	end)

	local slot = allocateSlot(player)
	OnboardingWorld.ensure(slot)

	local character = player.Character
	local session: Session = {
		player = player,
		slot = slot,
		step = resumeStep,
		resumed = resumed,
		startedAt = os.clock(),
		stepStartedAt = os.clock(),
		lastAttemptAt = os.clock(),
		attempts = 0,
		escalated = false,
		hint = "",
		dummyId = nil,
		practiceKnockouts = 0,
		practiceStartedAt = nil,
		advanceAt = nil,
		celebrateAt = nil,
		ballCheckedAt = os.clock(),
		returnCFrame = if character then character:GetPivot() else nil,
		partyPrompted = false,
		ending = false,
	}
	sessions[player] = session

	player:SetAttribute(ROUTE_ATTRIBUTE, "Training")
	placeCharacter(session)

	AnalyticsService.logCustomEvent(
		player,
		if resumed
			then AnalyticsConfig.CustomEvents.OnboardingResumed
			else AnalyticsConfig.CustomEvents.OnboardingStarted,
		1,
		{ deviceClass = deviceClass(player), resumed = resumed, stepId = resumeStep.Id }
	)
	logFunnel(session, "Started")
	enterStep(session, resumeStep)
end

local function resolveRoute(player: Player)
	local stored = PlayerData.getOnboarding(player)
	if stored == nil then
		-- Eligibility could not be resolved. Failing open is deliberate: a
		-- profile problem must never leave a player stuck behind training.
		player:SetAttribute(ROUTE_ATTRIBUTE, "Lobby")
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.OnboardingError, 1, {
			reason = "ProfileUnavailable",
			deviceClass = deviceClass(player),
		})
		return
	end
	local eligible = OnboardingState.isEligible(
		OnboardingState.migrate(stored, OnboardingConfig.Version),
		OnboardingConfig.Eligibility.AutoStartEnabled
	)
	AnalyticsService.logCustomEvent(
		player,
		AnalyticsConfig.CustomEvents.OnboardingEligible,
		if eligible then 1 else 0,
		{
			status = stored.Status,
			deviceClass = deviceClass(player),
		}
	)
	if not eligible then
		player:SetAttribute(ROUTE_ATTRIBUTE, "Lobby")
		return
	end
	beginSession(player, false)
end

local function onCharacterAdded(player: Player, character: Model)
	local session = sessions[player]
	if session == nil then
		return
	end
	-- A reset never restarts onboarding: the player comes back into the ring on
	-- the step they were already on.
	session.returnCFrame = character:GetPivot()
	task.defer(function()
		if sessions[player] ~= session then
			return
		end
		placeCharacter(session)
		if session.step.Weapon ~= "Hammer" then
			grantBall(session)
		end
		fire(player, "Recovered", { stepId = session.step.Id })
	end)
end

local function stepSessions()
	local now = os.clock()
	for player, session in sessions do
		if session.ending then
			continue
		end
		if player.Parent ~= Players then
			continue
		end

		if session.celebrateAt ~= nil then
			if now >= session.celebrateAt then
				session.celebrateAt = nil
				finishSession(session)
			end
			continue
		end

		if session.advanceAt ~= nil then
			if now >= session.advanceAt then
				local nextStep = OnboardingSteps.after(session.step.Id)
				session.advanceAt = nil
				if nextStep then
					enterStep(session, nextStep)
				end
			end
			continue
		end

		if now - session.startedAt >= OnboardingConfig.Timing.SessionTimeoutSeconds then
			endSession(player, "Timeout")
			continue
		end

		recoverFalls(session)
		ensureBall(session)
		restoreTargets(session)
		stepAssistance(session)

		if session.step.Id == "Practice" then
			PracticeBots.step(session.slot, now)
			local practiceStartedAt = session.practiceStartedAt
			if practiceStartedAt and now - practiceStartedAt >= OnboardingConfig.Training.PracticeMaxSeconds then
				completeStep(session)
			end
		elseif session.step.Id == "Hammer" then
			local dummyId = session.dummyId
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if dummyId and root and root:IsA("BasePart") and not TrainingDummies.isKnockedOut(dummyId) then
				-- The melee dummy waddles in and stops just inside hammer reach,
				-- so the very first swing connects.
				local dummyPosition = TrainingDummies.position(dummyId)
				if dummyPosition then
					local offset = root.Position - dummyPosition
					local flat = Vector3.new(offset.X, 0, offset.Z)
					if flat.Magnitude > Combat.Hammer.Range * 0.8 then
						TrainingDummies.walkTo(
							dummyId,
							root.Position - flat.Unit * OnboardingConfig.Training.HammerApproachStuds,
							OnboardingConfig.Training.DummyWalkSpeed
						)
					else
						TrainingDummies.stop(dummyId)
					end
				end
			end
		end
	end
end

function OnboardingService.isTraining(player: Player): boolean
	return sessions[player] ~= nil
end

function OnboardingService.anyTraining(): boolean
	return next(sessions) ~= nil
end

function OnboardingService.skip(player: Player)
	local session = sessions[player]
	if session == nil or not OnboardingConfig.Eligibility.SkipEnabled then
		return
	end
	local stepId = session.step.Id
	PlayerData.updateOnboarding(player, function(state)
		return OnboardingState.skip(state, stepId)
	end)
	endSession(player, "Skipped")
end

-- Voluntary replay. It is deliberately not gated on eligibility: a player who
-- finished may ask for training again, and doing so never demotes what they
-- have already earned.
function OnboardingService.replay(player: Player): boolean
	if sessions[player] ~= nil or PlayerData.getOnboarding(player) == nil then
		return false
	end
	beginSession(player, true)
	return sessions[player] ~= nil
end

-- Party phase is owned by PartyService; onboarding only reacts to it and never
-- writes party state, so training can neither dissolve a party nor be trapped
-- by one.
function OnboardingService.notifyPartyPhase(player: Player, phase: string?)
	local previous = partyPhases[player]
	partyPhases[player] = phase
	local session = sessions[player]
	if session == nil or phase == nil or phase == previous then
		return
	end
	if phase == "Assigned" or phase == "Teleporting" then
		-- A real match always wins. Progress is already persisted per step, so
		-- nothing is lost by leaving now.
		endSession(player, "PartyMatch")
		return
	end
	if (phase == "Queued" or phase == "Claimed") and not session.partyPrompted then
		session.partyPrompted = true
		fire(player, "PartyReady", { phase = phase })
	end
end

function OnboardingService.acceptPartyMatch(player: Player)
	if sessions[player] ~= nil then
		endSession(player, "PartyMatch")
	end
end

function OnboardingService.stateFor(player: Player): { [string]: any }?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	return {
		stepId = session.step.Id,
		index = session.step.Index,
		attempts = session.attempts,
		escalated = session.escalated,
		hint = session.hint,
		resumed = session.resumed,
	}
end

local ACTIONS: { [string]: (Player, any) -> any } = {
	Skip = function(player)
		OnboardingService.skip(player)
		return true
	end,
	Replay = function(player)
		return OnboardingService.replay(player)
	end,
	JoinPartyMatch = function(player)
		OnboardingService.acceptPartyMatch(player)
		return true
	end,
	KeepTraining = function(player)
		local session = sessions[player]
		if session then
			session.partyPrompted = true
		end
		return true
	end,
	GetState = function(player)
		return OnboardingService.stateFor(player)
	end,
}

function OnboardingService.start()
	if started then
		return
	end
	started = true

	-- Combat in the lobby is live exactly for players inside a training
	-- session, and for nobody else: an onboarding player's throws can never
	-- reach the lobby crowd, and a lobby player is never a combat character.
	CombatSession.setHost({
		isParticipant = function(player)
			local session = sessions[player]
			return session ~= nil and not session.ending
		end,
		isLive = function()
			return next(sessions) ~= nil
		end,
	})
	ServerAuthAdapter.setRuleOverride({ preserveDodgeballs = true })
	ServerAuthAdapter.registerCharacterSource("OnboardingDummies", TrainingDummies.characterSource)
	ServerAuthAdapter.onEvent(onSimEvent)
	BallService.start()
	ServerAuthAdapter.start()

	Network.handleProtected("OnboardingAction", {
		rateLimit = 6,
		validate = function(_player, action)
			return typeof(action) == "string" and ACTIONS[action] ~= nil, "invalid_action"
		end,
	}, function(player, action, payload)
		return ACTIONS[action](player, payload)
	end)

	PlayerData.onLoaded(resolveRoute)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if PlayerData.isLoaded(player) then
			task.spawn(resolveRoute, player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		endSession(player, "Left")
		partyPhases[player] = nil
	end)

	RunService.Heartbeat:Connect(stepSessions)
end

-- Developer tooling only; see OnboardingDebug for the guarded entry points.
function OnboardingService.forceStep(player: Player, stepId: string): boolean
	local step = OnboardingSteps.get(stepId)
	local session = sessions[player]
	if step == nil or session == nil then
		return false
	end
	session.advanceAt = nil
	session.celebrateAt = nil
	enterStep(session, step)
	return true
end

function OnboardingService.forceEnd(player: Player, reason: EndReason): boolean
	if sessions[player] == nil then
		return false
	end
	endSession(player, reason)
	return true
end

return OnboardingService
