-- Name: OnboardingService.luau
-- Author: Jack C.
-- Description: Server owner of first-session training: resolves eligibility from the profile, gives each learner their own arena, stages the encounter each step calls for, judges every hit against the real weapon geometry, and persists a checkpoint only once the player has actually performed the mechanic. The client presents; this module decides and remembers.
-- Created: 2026-08-26

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local OnboardingConfig = require(Config:WaitForChild("Interface"):WaitForChild("Onboarding"))
local AnalyticsConfig = require(Config:WaitForChild("Infra"):WaitForChild("Analytics"))
local CombatConfig = require(Config:WaitForChild("Gameplay"):WaitForChild("Combat"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local SharedGame = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local OnboardingState = require(SharedGame:WaitForChild("Onboarding"):WaitForChild("OnboardingState"))
local OnboardingHit = require(SharedGame:WaitForChild("Onboarding"):WaitForChild("OnboardingHit"))
local OnboardingLayout = require(SharedGame:WaitForChild("Onboarding"):WaitForChild("OnboardingLayout"))
local OnboardingAssist = require(SharedGame:WaitForChild("Onboarding"):WaitForChild("OnboardingAssist"))
local PlayerIds = require(SharedGame:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local ServerAuthAdapter = require(SharedGame:WaitForChild("Adapters"):WaitForChild("ServerAuthAdapter"))
local DevSoloPlay = require(SharedGame:WaitForChild("Matchmaking"):WaitForChild("DevSoloPlay"))
local PlayerData = require(script.Parent.Parent:WaitForChild("PlayerData"))
local AnalyticsService = require(script.Parent.Parent:WaitForChild("AnalyticsService"))
local OnboardingArena = require(script.Parent:WaitForChild("OnboardingArena"))
local OnboardingDummies = require(script.Parent:WaitForChild("OnboardingDummies"))
local OnboardingCombat = require(script.Parent:WaitForChild("OnboardingCombat"))

type Step = OnboardingState.Step
type Dummy = OnboardingDummies.Dummy
type BallSample = {
	ball: BasePart,
	previous: Vector3,
	current: Vector3,
	velocity: Vector3,
	ownerId: string?,
	charge: number?,
}

type Session = {
	player: Player,
	arena: OnboardingArena.Arena,
	step: Step,
	encounter: string?,
	dummies: { Dummy },
	chases: boolean,
	awaitingBridge: boolean,
	waypoint: Vector3?,
	startedAt: number,
	stepStartedAt: number,
	attempts: { [string]: number },
	escalated: { [string]: boolean },
	finished: boolean,
	generation: number,
	connections: { RBXScriptConnection },
}

local OnboardingService = {}

local PHASE_IN_FLIGHT = 2
local PHASE_BOUNCING = 3

-- Which encounter belongs to each step. Intro and the first throw share one, so
-- the dummy the player is about to be told to hit is already walking at them
-- before the prompt changes, rather than popping in on the word THROW.
local ENCOUNTER_FOR_STEP: { [string]: string } = {
	Intro = "Approach",
	NormalThrow = "Approach",
	Hammer = "Bonk",
	ChargedThrow = "Charge",
	Practice = "Brawl",
}

-- What the player should be doing right now. A step is not enough on its own:
-- the hammer lesson has a crossing before it has anything to hit, and the prompt
-- must never name a dummy that has not spawned yet.
local CUE_FOR_STEP: { [string]: string } = {
	Intro = "Ready",
	NormalThrow = "Throw",
	Hammer = "Bonk",
	ChargedThrow = "Charge",
	Practice = "Brawl",
	Celebration = "Done",
}

local BALL_GRANT_STEPS: { [string]: boolean } = {
	Intro = true,
	NormalThrow = true,
	ChargedThrow = true,
	Practice = true,
}
local BALL_HIT_STEPS: { [string]: boolean } = { NormalThrow = true, ChargedThrow = true, Practice = true }
local HAMMER_HIT_STEPS: { [string]: boolean } = { Hammer = true, Practice = true }

local started = false
local sessions: { [Player]: Session } = {}
local arenasInUse: { [number]: boolean } = {}
local ballPositions: { [BasePart]: Vector3 } = {}

local function readRecord(player: Player): OnboardingState.Record?
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	return OnboardingState.normalize(data.Onboarding, OnboardingConfig.Version)
end

local function writeRecord(player: Player, record: OnboardingState.Record)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	data.Onboarding.Status = record.Status
	data.Onboarding.Checkpoint = record.Checkpoint
	data.Onboarding.Version = record.Version
	data.Onboarding.SkippedAtStep = record.SkippedAtStep or ""
end

local function funnel(player: Player, entry: { step: number, name: string }, fields: { [string]: any }?)
	AnalyticsService.logFunnelStep(player, OnboardingConfig.Analytics.Funnel, entry.step, entry.name, fields)
end

local function allocateArena(): number
	local index = 1
	while arenasInUse[index] do
		index += 1
	end
	arenasInUse[index] = true
	return index
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Where a player belongs if they fall or stray onto the elimination ring. Before
-- the crossing that is the spawn pad; after it, the island end of the bridge, so
-- recovery never undoes progress the player already made on foot.
local function safeCFrame(session: Session): CFrame
	local step = session.step
	if step == "Intro" or step == "NormalThrow" then
		return session.arena.spawnCFrame
	end
	local landing = OnboardingArena.point(session.arena, OnboardingConfig.Training.BridgeWaypointDistance - 6, 0)
	local centre = session.arena.frame.origin
	return OnboardingArena.facing(landing + Vector3.new(0, 4, 0), Vector3.new(centre.x, centre.y, centre.z))
end

local function placeAtSafePoint(session: Session)
	local character = OnboardingCombat.ensureCharacter(session.player)
	if character == nil then
		return
	end
	character:PivotTo(safeCFrame(session))
end

local function clearDummies(session: Session)
	for _, dummy in session.dummies do
		OnboardingDummies.destroy(dummy)
	end
	table.clear(session.dummies)
end

local function standingTargets(session: Session): { Dummy }
	local standing: { Dummy } = {}
	for _, dummy in session.dummies do
		if OnboardingDummies.isStanding(dummy) then
			table.insert(standing, dummy)
		end
	end
	return standing
end

local function cueFor(session: Session): string
	if session.step == "Hammer" and session.awaitingBridge then
		return "Cross"
	end
	return CUE_FOR_STEP[session.step] or "Ready"
end

local function publish(session: Session, reason: string)
	local cue = cueFor(session)
	Network.fire("OnboardingState", session.player, {
		active = not session.finished,
		step = session.step,
		cue = cue,
		reason = reason,
		succeeded = reason == "hit",
		-- The crossing is a fixed place; the fight is whatever is walking at you.
		waypoint = if cue == "Cross" then session.waypoint else nil,
		trackTargets = cue == "Bonk",
		remaining = #standingTargets(session),
		attempts = session.attempts[session.step] or 0,
		escalated = session.escalated[session.step] == true,
	})
end

-- Assistance widens the target rather than shortening the lesson: a struggling
-- player gets a more forgiving dummy, never a step that finishes without them.
local function targetRadius(session: Session, dummy: Dummy): number
	local training = OnboardingConfig.Training
	local leniency = if session.escalated[session.step]
		then training.EscalatedLeniencyStuds
		else training.TargetLeniencyStuds
	return dummy.radius + leniency
end

-- The only path that finishes a lesson. A step advances once every dummy it
-- staged is down and the knock-back has had time to read; nothing else completes
-- a step, so the player has always performed the mechanic being taught.
local function knockTarget(session: Session, dummy: Dummy, fromPosition: Vector3)
	if not OnboardingDummies.isStanding(dummy) then
		return
	end
	OnboardingDummies.knock(dummy, fromPosition)
	publish(session, "hit")

	local step = session.step
	local generation = session.generation
	task.delay(OnboardingConfig.Timing.SuccessHoldSeconds, function()
		if sessions[session.player] ~= session or session.finished or session.generation ~= generation then
			return
		end
		if #standingTargets(session) > 0 then
			return
		end
		OnboardingService.completeStep(session.player, step)
	end)
end

local function ballsFolder(): Folder?
	local folder = Workspace:FindFirstChild("Balls")
	return if folder and folder:IsA("Folder") then folder else nil
end

-- Balls are shared world state, so they are sampled once per frame for every
-- session at once. Sampling per session would compare a ball against itself and
-- collapse the swept segment the contact test depends on.
local function sampleBalls(): { BallSample }
	local folder = ballsFolder()
	if folder == nil then
		table.clear(ballPositions)
		return {}
	end
	local samples: { BallSample } = {}
	local live: { [BasePart]: boolean } = {}
	for _, ball in folder:GetChildren() do
		if not ball:IsA("BasePart") then
			continue
		end
		live[ball] = true
		local current = ball.CFrame.Position
		local previous = ballPositions[ball] or current
		ballPositions[ball] = current
		local phase = ball:GetAttribute("ph")
		if phase ~= PHASE_IN_FLIGHT and phase ~= PHASE_BOUNCING then
			continue
		end
		local velocity = ball:GetAttribute("vel")
		table.insert(samples, {
			ball = ball,
			previous = previous,
			current = current,
			velocity = if typeof(velocity) == "Vector3" then velocity else Vector3.zero,
			ownerId = ball:GetAttribute("ow") :: string?,
			charge = ball:GetAttribute("rc") :: number?,
		})
	end
	for ball in ballPositions do
		if not live[ball] then
			ballPositions[ball] = nil
		end
	end
	return samples
end

-- Velocity round-trips through the codec every tick, so nudging it between
-- steps is picked up by the next decode. Only the heading is touched, and only
-- toward a dummy the throw was already pointed near.
local function steerBalls(session: Session, samples: { BallSample }, dt: number)
	if not BALL_HIT_STEPS[session.step] then
		return
	end
	local standing = standingTargets(session)
	if #standing == 0 then
		return
	end
	local assist = OnboardingConfig.Assist
	local playerId = PlayerIds.toId(session.player)
	local maxTurn = math.rad(assist.TurnRateDegPerSecond) * dt
	local acquireCosine = math.cos(math.rad(assist.AcquireConeDeg))

	for _, sample in samples do
		if sample.ownerId ~= playerId then
			continue
		end
		local best: Vector3? = nil
		local bestDistance = math.huge
		for _, dummy in standing do
			local at = OnboardingDummies.position(dummy)
			local distance = (at - sample.current).Magnitude
			if distance < bestDistance then
				best = at
				bestDistance = distance
			end
		end
		if best == nil then
			continue
		end
		local steered =
			OnboardingAssist.steer(sample.current, sample.velocity, best, maxTurn, acquireCosine, assist.MaxRangeStuds)
		if steered ~= nil then
			sample.ball:SetAttribute("vel", steered)
		end
	end
end

local function detectBallHits(session: Session, samples: { BallSample })
	if not BALL_HIT_STEPS[session.step] then
		return
	end
	local playerId = PlayerIds.toId(session.player)
	local requiresCharge = session.step == "ChargedThrow"
	for _, sample in samples do
		if sample.ownerId ~= playerId then
			continue
		end
		-- The charge lesson is only satisfied by an actually charged release, so
		-- a reflexive tap cannot pass it.
		if requiresCharge and (sample.charge or 0) < OnboardingConfig.Training.MinimumChargeAlpha then
			continue
		end
		for _, dummy in standingTargets(session) do
			local at = OnboardingDummies.position(dummy)
			if OnboardingHit.ballReachedTarget(sample.previous, sample.current, at, targetRadius(session, dummy)) then
				knockTarget(session, dummy, sample.current)
			end
		end
	end
end

-- The dummies are not simulation entities, so the hammer can never report a hit
-- on one. The swing itself is authoritative and carries its own origin and
-- direction, which is enough to re-run the weapon real cone against a target.
local function onSimEvent(event: { [string]: any })
	if event.kind ~= "HammerSwing" then
		return
	end
	local player = PlayerIds.fromEvent(event)
	local session = if player then sessions[player] else nil
	if session == nil or session.finished or not HAMMER_HIT_STEPS[session.step] then
		return
	end
	local origin, direction = event.position, event.direction
	if origin == nil or direction == nil then
		return
	end
	for _, dummy in standingTargets(session) do
		local at = OnboardingDummies.position(dummy)
		local radius = targetRadius(session, dummy)
		if OnboardingHit.withinHammerCone(origin, direction, at, radius, CombatConfig.Hammer) then
			-- One swing takes one target, matching the sim own resolution.
			knockTarget(session, dummy, origin)
			return
		end
	end
end

local function spawnDummyAt(session: Session, position: Vector3, walkSpeed: number): Dummy
	local facing = OnboardingArena.facing(position, session.arena.spawnCFrame.Position)
	local dummy = OnboardingDummies.spawn(facing, session.arena.model, walkSpeed, PlayerIds.toId(session.player))
	table.insert(session.dummies, dummy)
	return dummy
end

local function buildEncounter(session: Session, encounter: string)
	local training = OnboardingConfig.Training
	if encounter == "Approach" then
		spawnDummyAt(
			session,
			OnboardingArena.point(session.arena, training.ThrowDummyDistance, 0),
			training.ThrowDummyWalkSpeed
		)
		session.chases = true
	elseif encounter == "Bonk" then
		-- Held back until the player commits to the crossing, so the lesson is
		-- "something ran at me on the bridge" rather than a dummy stood waiting.
		session.waypoint = OnboardingArena.point(session.arena, training.BridgeWaypointDistance, 0)
		session.awaitingBridge = true
		session.chases = true
	elseif encounter == "Charge" then
		spawnDummyAt(session, OnboardingArena.point(session.arena, training.ChargeDummyDistance, 0), 0)
		session.chases = false
	elseif encounter == "Brawl" then
		for index = 1, training.BrawlDummyCount do
			spawnDummyAt(
				session,
				OnboardingArena.ringPoint(session.arena, training.BrawlRingRadius, index, training.BrawlDummyCount),
				training.BrawlDummyWalkSpeed
			)
		end
		session.chases = true
	end
end

local function stageStep(session: Session, step: Step)
	session.generation += 1

	local wanted = ENCOUNTER_FOR_STEP[step]
	if wanted ~= session.encounter then
		clearDummies(session)
		session.encounter = wanted
		session.waypoint = nil
		session.awaitingBridge = false
		session.chases = false
		if wanted ~= nil then
			buildEncounter(session, wanted)
		end
	end

	if BALL_GRANT_STEPS[step] then
		OnboardingCombat.grantBall(session.player)
	else
		-- A preserved ball returns straight to its owner's hand, and gaining a
		-- hand ball is exactly what makes the simulation auto-equip the
		-- dodgeball. Taking the ball away is what keeps the hammer lesson about
		-- the hammer, without any weapon state needing to be forced back.
		OnboardingCombat.clearBall(session.player)
	end

	local generation = session.generation
	if step == "Intro" then
		-- The intro is a beat, not a gate: nothing to press, it simply hands
		-- control over once the player has landed and read one short line.
		task.delay(OnboardingConfig.Timing.IntroSeconds, function()
			if session.generation == generation and not session.finished then
				OnboardingService.completeStep(session.player, "Intro")
			end
		end)
	elseif step == "Celebration" then
		task.delay(OnboardingConfig.Timing.CelebrationSeconds, function()
			if session.generation == generation and not session.finished then
				OnboardingService.complete(session.player)
			end
		end)
	end
end

local function endSession(player: Player, reason: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.finished = true
	session.generation += 1
	for _, connection in session.connections do
		connection:Disconnect()
	end
	table.clear(session.connections)
	clearDummies(session)
	OnboardingArena.destroy(session.arena)
	OnboardingCombat.release(player)
	arenasInUse[session.arena.index] = nil
	sessions[player] = nil
	Network.fire("OnboardingState", player, { active = false, step = session.step, reason = reason })
end

function OnboardingService.sessionFor(player: Player): Session?
	return sessions[player]
end

function OnboardingService.beginFor(player: Player, forcedStep: Step?): (boolean, string?)
	if sessions[player] ~= nil then
		return false, "already_active"
	end
	local record = readRecord(player)
	if record == nil then
		return false, "no_profile"
	end
	if forcedStep == nil and not OnboardingState.isEligible(record) then
		return false, "not_eligible"
	end
	if forcedStep == nil and not OnboardingConfig.Eligibility.AutoStartEnabled then
		return false, "disabled"
	end

	local resumeAt = forcedStep or OnboardingState.resumeStep(record, OnboardingConfig.Eligibility.ResumeEnabled)
	local now = os.clock()
	local session: Session = {
		player = player,
		arena = OnboardingArena.build(allocateArena()),
		step = resumeAt,
		encounter = nil,
		dummies = {},
		chases = false,
		awaitingBridge = false,
		waypoint = nil,
		startedAt = now,
		stepStartedAt = now,
		attempts = {},
		escalated = {},
		finished = false,
		generation = 0,
		connections = {},
	}
	sessions[player] = session
	OnboardingCombat.admit(player)

	if record.Status == OnboardingState.Statuses.NotStarted then
		writeRecord(player, OnboardingState.withCheckpoint(record, "Intro"))
	end

	funnel(player, OnboardingConfig.Analytics.Steps.Started, {
		resumed = resumeAt ~= "Intro",
		resumeStep = resumeAt,
	})

	-- A reset or a fall must land the player back in their own arena on the step
	-- they were already on, never in the lobby and never at step one.
	table.insert(
		session.connections,
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if sessions[player] == session and not session.finished then
				placeAtSafePoint(session)
			end
		end)
	)

	stageStep(session, resumeAt)
	placeAtSafePoint(session)
	publish(session, if resumeAt ~= "Intro" then "resumed" else "started")
	return true, nil
end

-- The only path that writes progress. Transitions are checked against the
-- session own current step, so a stale or forged message cannot skip a player
-- forward to CoreComplete.
function OnboardingService.completeStep(player: Player, step: Step): (boolean, string?)
	local session = sessions[player]
	if session == nil then
		return false, "no_session"
	end
	if not OnboardingState.isStep(step) or step ~= session.step then
		return false, "wrong_step"
	end

	local record = readRecord(player)
	if record == nil then
		return false, "no_profile"
	end

	local entry = OnboardingConfig.Analytics.Steps[step]
	if entry then
		funnel(player, entry, {
			durationMs = math.round((os.clock() - session.stepStartedAt) * 1000),
			attempts = session.attempts[step] or 0,
			escalated = session.escalated[step] == true,
		})
	end

	writeRecord(player, OnboardingState.withCheckpoint(record, step))

	local nextStep = OnboardingState.nextStep(step)
	if nextStep == nil then
		OnboardingService.complete(player)
		return true, nil
	end

	session.step = nextStep
	session.stepStartedAt = os.clock()
	stageStep(session, nextStep)
	publish(session, "advanced")
	return true, nil
end

function OnboardingService.recordAttempt(player: Player, escalated: boolean?)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.attempts[session.step] = (session.attempts[session.step] or 0) + 1
	if escalated then
		session.escalated[session.step] = true
	end
end

function OnboardingService.complete(player: Player): (boolean, string?)
	local session = sessions[player]
	local record = readRecord(player)
	if record == nil then
		return false, "no_profile"
	end
	writeRecord(player, OnboardingState.withCompletion(record, OnboardingConfig.Version))
	funnel(player, OnboardingConfig.Analytics.Steps.Completed, {
		durationMs = if session then math.round((os.clock() - session.startedAt) * 1000) else 0,
	})
	endSession(player, "completed")
	return true, nil
end

function OnboardingService.skip(player: Player): (boolean, string?)
	if not OnboardingConfig.Eligibility.SkipEnabled then
		return false, "skip_disabled"
	end
	local session = sessions[player]
	local record = readRecord(player)
	if record == nil then
		return false, "no_profile"
	end
	local atStep: Step = if session then session.step else "Intro"
	writeRecord(player, OnboardingState.withSkip(record, atStep))
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.OnboardingSkipped, 1, {
		step = atStep,
		durationMs = if session then math.round((os.clock() - session.startedAt) * 1000) else 0,
	})
	endSession(player, "skipped")
	return true, nil
end

-- Called when a real match takes priority over training. The player keeps every
-- checkpoint they earned; the session simply stops so it can never block a
-- legitimate social transition.
function OnboardingService.cancel(player: Player, reason: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.OnboardingAbandoned, 1, {
		step = session.step,
		reason = reason,
		durationMs = math.round((os.clock() - session.startedAt) * 1000),
	})
	endSession(player, reason)
end

function OnboardingService.isActive(player: Player): boolean
	return sessions[player] ~= nil
end

function OnboardingService.resolveFor(player: Player): { eligible: boolean, step: Step?, status: string }
	local record = readRecord(player)
	if record == nil then
		return { eligible = false, step = nil, status = "unresolved" }
	end
	local eligible = OnboardingState.isEligible(record) and OnboardingConfig.Eligibility.AutoStartEnabled
	return {
		eligible = eligible,
		step = if eligible then OnboardingState.resumeStep(record, OnboardingConfig.Eligibility.ResumeEnabled) else nil,
		status = record.Status,
	}
end

-- No lesson is on a timer, so a ball that is somehow lost would strand the
-- player on a step they can no longer attempt. Preserved dodgeballs normally
-- return on their own; this only covers owning none at all.
local function ensureBallAvailable(session: Session)
	if not BALL_GRANT_STEPS[session.step] then
		return
	end
	local folder = ballsFolder()
	if folder == nil then
		OnboardingCombat.grantBall(session.player)
		return
	end
	local playerId = PlayerIds.toId(session.player)
	for _, ball in folder:GetChildren() do
		if ball:IsA("BasePart") and ball:GetAttribute("ow") == playerId then
			return
		end
	end
	OnboardingCombat.grantBall(session.player)
end

local function releaseBridgeDummy(session: Session, position: Vector3)
	local world = OnboardingConfig.World
	local onBridge = OnboardingLayout.onBridge(
		session.arena.frame,
		position,
		world.BridgeInnerRadius,
		world.BridgeOuterRadius,
		world.BridgeHalfWidth
	)
	if not onBridge then
		return
	end
	session.awaitingBridge = false
	spawnDummyAt(
		session,
		OnboardingArena.point(session.arena, OnboardingConfig.Training.BonkDummyDistance, 0),
		OnboardingConfig.Training.BonkDummyWalkSpeed
	)
	publish(session, "advanced")
end

local function recoverIfLost(session: Session, position: Vector3)
	local world = OnboardingConfig.World
	local frame = session.arena.frame
	local fallen = position.Y < frame.surfaceY - world.FallRecoveryDepth
	local strayed = OnboardingLayout.overEliminationRing(
		frame,
		position,
		world.RingInnerRadius,
		world.RingOuterRadius,
		world.BridgeHalfWidth
	)
	if fallen or strayed then
		placeAtSafePoint(session)
	end
end

local function tickSession(session: Session, samples: { BallSample }, now: number, dt: number, recover: boolean)
	steerBalls(session, samples, dt)
	detectBallHits(session, samples)

	local root = characterRoot(session.player)
	local chaseTarget = if session.chases and root ~= nil then root.Position else nil
	for _, dummy in standingTargets(session) do
		OnboardingDummies.update(dummy, now, chaseTarget)
	end

	if root ~= nil then
		local position = root.Position
		if session.awaitingBridge then
			releaseBridgeDummy(session, position)
		end
		if recover then
			recoverIfLost(session, position)
		end
	end

	if recover then
		ensureBallAvailable(session)
	end
end

function OnboardingService.start()
	if started then
		return
	end
	started = true
	OnboardingArena.clearAll()

	ServerAuthAdapter.onEvent(onSimEvent)

	-- One loop drives every session: ball contact, dummy pursuit, the bridge
	-- trigger and recovery. Keeping it at service scope rather than per step
	-- means staging a step can never silently tear any of it down.
	local recoveryAccumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if next(sessions) == nil then
			return
		end
		local samples = sampleBalls()
		local now = os.clock()
		recoveryAccumulator += dt
		local recover = recoveryAccumulator >= 0.5
		if recover then
			recoveryAccumulator = 0
		end
		for _, session in sessions do
			if not session.finished then
				tickSession(session, samples, now, dt, recover)
			end
		end
	end)

	Network.handleProtected("OnboardingReady", { rateLimit = 3 }, function(player)
		local resolution = OnboardingService.resolveFor(player)
		if resolution.eligible then
			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.OnboardingEligible, 1, {
				step = resolution.step,
			})
			local ok = OnboardingService.beginFor(player)
			return { eligible = ok, step = resolution.step, status = resolution.status }
		end
		return { eligible = false, step = nil, status = resolution.status }
	end)

	Network.handleProtected("OnboardingAction", {
		rateLimit = 12,
		validate = function(_player, action, payload)
			if typeof(action) ~= "string" then
				return false, "invalid_action"
			end
			if payload ~= nil and typeof(payload) ~= "string" then
				return false, "invalid_payload"
			end
			return true
		end,
	}, function(player, action, payload)
		if action == "Attempt" then
			OnboardingService.recordAttempt(player, payload == "escalated")
		elseif action == "Skip" then
			OnboardingService.skip(player)
		end
	end)

	-- Debug actions share the group-rank gate the lobby dev solo-play path uses,
	-- so they can never be driven by an ordinary production client and cannot
	-- corrupt a real player saved progression.
	Network.handleProtected("OnboardingDebug", {
		rateLimit = 4,
		validate = function(player, action, payload)
			if not DevSoloPlay.canUse(player) then
				return false, "not_developer"
			end
			if typeof(action) ~= "string" then
				return false, "invalid_action"
			end
			if payload ~= nil and typeof(payload) ~= "string" then
				return false, "invalid_payload"
			end
			return true
		end,
	}, function(player, action, payload)
		if action == "Reset" then
			OnboardingService.cancel(player, "debug_reset")
			writeRecord(player, OnboardingState.blank(OnboardingConfig.Version))
		elseif action == "ForceStart" then
			OnboardingService.cancel(player, "debug_restart")
			OnboardingService.beginFor(player, if OnboardingState.isStep(payload) then payload :: Step else "Intro")
		elseif action == "MarkCoreComplete" then
			local record = readRecord(player)
			if record then
				local staged = OnboardingState.withCheckpoint(record, "NormalThrow")
				staged = OnboardingState.withCheckpoint(staged, "Hammer")
				staged = OnboardingState.withCheckpoint(staged, "ChargedThrow")
				writeRecord(player, staged)
			end
		elseif action == "CompleteNow" then
			OnboardingService.complete(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.OnboardingAbandoned, 1, {
				step = session.step,
				reason = "left",
				durationMs = math.round((os.clock() - session.startedAt) * 1000),
			})
			endSession(player, "left")
		end
	end)
end

return OnboardingService
