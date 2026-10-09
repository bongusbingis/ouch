--!strict
-- Server-owned obstacle lessons. Retains first-session eligibility, resumable
-- checkpoints, skip, analytics and social cancellation from the combat tutorial.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local OnboardingConfig = require(Config:WaitForChild("Interface"):WaitForChild("Onboarding"))
local AnalyticsConfig = require(Config:WaitForChild("Infra"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local SharedGame = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local OnboardingState = require(SharedGame:WaitForChild("Onboarding"):WaitForChild("OnboardingState"))
local DevSoloPlay = require(SharedGame:WaitForChild("Matchmaking"):WaitForChild("DevSoloPlay"))
local PlayerData = require(script.Parent.Parent:WaitForChild("PlayerData"))
local AnalyticsService = require(script.Parent.Parent:WaitForChild("AnalyticsService"))
local OnboardingArena = require(script.Parent:WaitForChild("OnboardingArena"))
local OnboardingCombat = require(script.Parent:WaitForChild("OnboardingCombat"))

local Course = require(script.Parent.OnboardingCourse)
local Progress = require(SharedGame.Onboarding.OnboardingProgress)
local RotatingPlatforms = require(SharedGame.MapFeatures.RotatingPlatforms)
local ShoveFeature = require(script.Parent.Parent.TrainingHazards.ShoveFeature)
local L = OnboardingConfig.Course

type Step = OnboardingState.Step
type Session = {
	player: Player,
	arena: Course.Course,
	step: Step,
	checkpoint: number,
	targetIndex: number,
	jumped: boolean,
	retryAt: number?,
	graceUntil: number,
	succeeded: boolean,
	startedAt: number,
	stepStartedAt: number,
	attempts: { [string]: number },
	escalated: { [string]: boolean },
	finished: boolean,
	generation: number,
	connections: { RBXScriptConnection },
	returnCFrame: CFrame?,
	debugRecord: OnboardingState.Record?,
}
local OnboardingService = {}
local started = false
local sessions: { [Player]: Session } = {}
local arenasInUse: { [number]: boolean } = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function readRecord(player: Player): OnboardingState.Record?
	local session = sessions[player]
	if session and session.debugRecord then
		return table.clone(session.debugRecord)
	end
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	return OnboardingState.normalize(data.Onboarding, OnboardingConfig.Version)
end

local function writeRecord(player: Player, record: OnboardingState.Record)
	local session = sessions[player]
	if session and session.debugRecord then
		session.debugRecord = table.clone(record)
		return
	end
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

local function lessonFor(session: Session)
	return L.Lessons[session.step] or L.Lessons.AvoidBumpers
end

local function targetFor(session: Session): number
	local lesson = lessonFor(session)
	return lesson.checkpoints[session.targetIndex] or lesson.checkpoints[#lesson.checkpoints]
end

local function publish(session: Session, reason: string)
	Network.fire("OnboardingState", session.player, {
		active = not session.finished,
		step = session.step,
		cue = session.step,
		reason = reason,
		succeeded = session.succeeded,
		retrying = session.retryAt ~= nil,
		facing = Course.direction(session.arena, session.checkpoint, targetFor(session)),
		waypoint = if session.step ~= "Celebration" then Course.position(session.arena, targetFor(session)) else nil,
		trackTargets = false,
		checkpoint = session.targetIndex - 1,
		checkpointCount = #lessonFor(session).checkpoints,
	})
end

local function placeAtSafePoint(session: Session)
	local character = OnboardingCombat.ensureCharacter(session.player)
	if not character or sessions[session.player] ~= session or session.finished then
		return
	end
	ShoveFeature.forget(session.player)
	character:PivotTo(Course.spawnAt(session.arena, session.checkpoint, targetFor(session)))
	local root = characterRoot(session.player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		MovementGuard.reset(root)
	end
	session.jumped = false
	session.retryAt = nil
	session.graceUntil = os.clock() + L.RecoveryGraceSeconds
end

local function stageStep(session: Session, step: Step)
	session.generation += 1
	session.targetIndex = 1
	session.jumped = false
	session.succeeded = false
	session.retryAt = nil
	session.checkpoint = if step == "Celebration" then L.Lessons.Practice.checkpoints[3] else lessonFor(session).start
	local generation = session.generation
	if step == "Intro" or step == "Celebration" then
		task.delay(
			if step == "Intro" then OnboardingConfig.Timing.IntroSeconds else OnboardingConfig.Timing.CelebrationSeconds,
			function()
				if sessions[session.player] ~= session or session.generation ~= generation or session.finished then
					return
				end
				if step == "Intro" then
					OnboardingService.completeStep(session.player, "Intro")
				else
					OnboardingService.complete(session.player)
				end
			end
		)
	end
end

local function endSession(player: Player, reason: string)
	local session = sessions[player]
	if not session then
		return
	end
	session.finished = true
	session.generation += 1
	for _, connection in session.connections do
		connection:Disconnect()
	end
	table.clear(session.connections)
	ShoveFeature.forget(player)
	OnboardingCombat.clearBall(player)
	OnboardingCombat.release(player)
	local root = characterRoot(player)
	if root and session.returnCFrame then
		(player.Character :: Model):PivotTo(session.returnCFrame)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		MovementGuard.reset(root)
	end
	Course.destroy(session.arena)
	arenasInUse[session.arena.index] = nil
	sessions[player] = nil
	Network.fire("OnboardingState", player, { active = false, step = session.step, reason = reason })
end

function OnboardingService.sessionFor(player: Player): Session?
	return sessions[player]
end

function OnboardingService.beginFor(player: Player, forcedStep: Step?): (boolean, string?)
	if sessions[player] then
		return false, "already_active"
	end
	local record = readRecord(player)
	if not record then
		return false, "no_profile"
	end
	if forcedStep == nil and not OnboardingState.isEligible(record) then
		return false, "not_eligible"
	end
	if forcedStep == nil and not OnboardingConfig.Eligibility.AutoStartEnabled then
		return false, "disabled"
	end
	if forcedStep and not OnboardingState.isStep(forcedStep) then
		return false, "invalid_step"
	end
	local character = OnboardingCombat.ensureCharacter(player)
	if not character then
		return false, "no_character"
	end
	local resumeAt = forcedStep or OnboardingState.resumeStep(record, OnboardingConfig.Eligibility.ResumeEnabled)
	local now = os.clock()
	local session: Session = {
		player = player,
		arena = Course.build(allocateArena()),
		step = resumeAt,
		checkpoint = L.Lessons.AvoidBumpers.start,
		targetIndex = 1,
		jumped = false,
		retryAt = nil,
		succeeded = false,
		graceUntil = now,
		startedAt = now,
		stepStartedAt = now,
		attempts = {},
		escalated = {},
		finished = false,
		generation = 0,
		connections = {},
		returnCFrame = character:GetPivot(),
		-- Forced developer sessions exercise progression without saving it.
		debugRecord = if forcedStep then OnboardingState.blank(OnboardingConfig.Version) else nil,
	}
	sessions[player] = session
	-- No ArenaReady admission: the lobby's developer combat stack cannot give
	-- learners weapons or accept combat commands during the obstacle lessons.
	OnboardingCombat.clearBall(player)
	OnboardingCombat.release(player)
	if record.Status == OnboardingState.Statuses.NotStarted then
		record.Version = OnboardingConfig.Version
		writeRecord(player, OnboardingState.withCheckpoint(record, "Intro"))
	end
	funnel(player, OnboardingConfig.Analytics.Steps.Started, { resumed = resumeAt ~= "Intro", resumeStep = resumeAt })
	table.insert(
		session.connections,
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if sessions[player] == session and not session.finished then
				placeAtSafePoint(session)
				publish(session, "recovered")
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

	if step ~= "Intro" and step ~= "Celebration" and not session.succeeded then
		return false, "not_demonstrated"
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

local function retry(session: Session, now: number)
	if session.retryAt or session.succeeded then
		return
	end
	session.jumped = false
	session.retryAt = now + L.RetrySeconds
	session.attempts[session.step] = (session.attempts[session.step] or 0) + 1
	publish(session, "retry")
end

local function tickSession(session: Session, now: number)
	local root = characterRoot(session.player)
	if not root then
		return
	end
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local position = Course.localPosition(session.arena, root.Position)
	if session.retryAt then
		if now >= session.retryAt then
			placeAtSafePoint(session)
			publish(session, "recovered")
		end
		return
	end
	if Progress.isLost(position, OnboardingConfig.World) then
		placeAtSafePoint(session)
		publish(session, "recovered")
		return
	end
	if session.step == "Intro" or session.step == "Celebration" or session.succeeded then
		return
	end
	-- Query the real hazard collision geometry before awarding a checkpoint.
	-- This is the same root-only overlap used by Splashdown's shared shove kits.
	if now >= session.graceUntil then
		overlap.FilterDescendantsInstances = { root }
		for _, hazard in session.arena.hazards do
			if #Workspace:GetPartsInPart(hazard, overlap) > 0 then
				retry(session, now)
				return
			end
		end
	end
	local lesson = lessonFor(session)
	local target = targetFor(session)
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if Progress.jumpedAt(position, lesson.jumpAt, not grounded, root.AssemblyLinearVelocity.Y > 2) then
		session.jumped = true
	end
	if not Progress.atCheckpoint(position, target, grounded, L) then
		return
	end
	if Progress.needsJump(lesson.jumpAt, session.checkpoint, target) and not session.jumped then
		retry(session, now)
		return
	end
	if session.targetIndex < #lesson.checkpoints then
		session.checkpoint = target
		session.targetIndex += 1
		session.jumped = false
		publish(session, "checkpoint")
		return
	end
	session.checkpoint = target
	session.succeeded = true
	publish(session, "success")
	local generation = session.generation
	local step = session.step
	task.delay(OnboardingConfig.Timing.SuccessHoldSeconds, function()
		if sessions[session.player] == session and not session.finished and session.generation == generation then
			OnboardingService.completeStep(session.player, step)
		end
	end)
end

function OnboardingService.start()
	if started then
		return
	end
	started = true
	OnboardingArena.clearAll()
	RotatingPlatforms.startMover()
	RunService.Heartbeat:Connect(function(dt)
		if next(sessions) == nil then
			return
		end
		local now = os.clock()
		local groups: { Instance } = {}
		for _, session in sessions do
			table.insert(groups, session.arena.group)
		end
		local context = { instances = groups, now = now, deltaTime = dt }
		ShoveFeature.tickWorld(context)
		for player, session in sessions do
			if session.finished then
				continue
			end
			local root = characterRoot(player)
			if root and now >= session.graceUntil and not session.succeeded then
				ShoveFeature.tickPlayer(context, player, root)
			end
			tickSession(session, now)
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
				local staged = OnboardingState.withCheckpoint(record, "AvoidBumpers")
				staged = OnboardingState.withCheckpoint(staged, "JumpSweepers")
				staged = OnboardingState.withCheckpoint(staged, "TimeHammer")
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
