-- Description: Owns the arena server's matchmaking session identity: validates arriving teleport payloads and their source place, establishes which queue and mode selection this server plays, tracks admission and party identity across reconnects, and gates the start of play on client readiness.

--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnalyticsConfig = require(Config:WaitForChild("Infra"):WaitForChild("Analytics"))
local Debug = require(Config:WaitForChild("Infra"):WaitForChild("Debug"))
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Queues = require(Config:WaitForChild("Gameplay"):WaitForChild("Queues"))
local Loading = require(Config:WaitForChild("Interface"):WaitForChild("Loading"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Matchmaking = Shared:WaitForChild("Game"):WaitForChild("Matchmaking")
local ArenaReadinessGate = require(Matchmaking:WaitForChild("ArenaReadinessGate"))
local ModeOptions = require(Shared:WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeOptions"))
local Network = require(Shared:WaitForChild("Network"))
local TeleportPayload = require(Matchmaking:WaitForChild("TeleportPayload"))

local AnalyticsService = require(script.Parent.AnalyticsService)
local PlayerData = require(script.Parent.PlayerData)
local Env = require(script.Parent.Parent.Env)

local ArenaSessionService = {}

export type Snapshot = {
	matchId: string,
	queueId: string,
	fixedModeId: string?,
	expectedPlayerCount: number,
	modeOptions: { string },
	arrivedPlayerCount: number,
	readyPlayerCount: number,
	deadlineAt: number,
	gateReleased: boolean,
}

export type Admission = "Direct" | "Matched" | "Rejected"

type Session = {
	matchId: string,
	expectedPlayerCount: number,
	queueId: string,
	modeOptions: { string },
	fixedModeId: string?,
}

-- What this server plays, fixed by its first arrival: a matched session's
-- payload, or the Studio queue for a direct play session.
type Identity = {
	queueId: string,
	modeOptions: { string },
	fixedModeId: string?,
}

type PartyContext = {
	partyId: string,
	leaderUserId: number,
	memberUserIds: { number },
}

local LOAD_STATE_FOLDER_NAME = "ArenaLoadState"
local LOAD_SNAPSHOT_NAME = "Snapshot"
local LOAD_SCHEMA_VERSION = 2
local READY_ATTRIBUTE = "ArenaReady"
local READINESS_DEADLINE_SECONDS = Loading.ArenaWaitSeconds

local session: Session? = nil
local identity: Identity? = nil
local gate: ArenaReadinessGate.State? = nil
local partyByUserId: { [number]: string } = {}
local partyById: { [string]: PartyContext } = {}
local readyListeners: { (Player) -> () } = {}
local roundEligibilityListeners: { (Player, boolean) -> () } = {}
local gateReleasedListeners: { (string) -> () } = {}
local sessionListeners: { (string, string?) -> () } = {}
local loadSnapshotValue: StringValue? = nil
local loadRevision = 0
local gateGeneration = 0
local started = false

local function sameMembers(first: { number }, second: { number }): boolean
	if #first ~= #second then
		return false
	end
	for _, userId in first do
		if not table.find(second, userId) then
			return false
		end
	end
	return true
end

local function registerParty(player: Player, partyId: string, payloadParty: TeleportPayload.PartyContext?): boolean
	local current = partyById[partyId]
	if payloadParty then
		if not table.find(payloadParty.memberUserIds, player.UserId) then
			return false
		end
		if
			current
			and (
				current.leaderUserId ~= payloadParty.leaderUserId
				or not sameMembers(current.memberUserIds, payloadParty.memberUserIds)
			)
		then
			return false
		end
		if current == nil then
			partyById[partyId] = {
				partyId = partyId,
				leaderUserId = payloadParty.leaderUserId,
				memberUserIds = table.clone(payloadParty.memberUserIds),
			}
		end
	elseif current == nil then
		partyById[partyId] = {
			partyId = partyId,
			leaderUserId = player.UserId,
			memberUserIds = { player.UserId },
		}
	elseif not table.find(current.memberUserIds, player.UserId) then
		table.insert(current.memberUserIds, player.UserId)
		table.sort(current.memberUserIds)
	end
	partyByUserId[player.UserId] = partyId
	return true
end

local function ensureLoadState(): StringValue
	if loadSnapshotValue then
		return loadSnapshotValue
	end

	local folder = Instance.new("Folder")
	folder.Name = LOAD_STATE_FOLDER_NAME
	local snapshot = Instance.new("StringValue")
	snapshot.Name = LOAD_SNAPSHOT_NAME
	snapshot.Parent = folder
	folder.Parent = ReplicatedStorage
	loadSnapshotValue = snapshot
	return snapshot
end

local function currentModeOptions(): { string }
	return if identity then table.clone(identity.modeOptions) else table.clone(GameModes.VoteOptions)
end

-- A fixed selection resolves to exactly its mode or nothing: the ballot fallback
-- ModeOptions applies to a vote would silently turn a race server into a brawl.
local function resolveSelection(selection: TeleportPayload.ModeSelection): ({ string }?, string?)
	if selection.strategy == "Fixed" then
		local resolved = ModeOptions.resolve({ selection.modeId })
		if #resolved ~= 1 or resolved[1] ~= selection.modeId then
			return nil, nil
		end
		return resolved, selection.modeId
	end
	local resolved = ModeOptions.resolve(selection.options)
	return if #resolved > 0 then resolved else nil, nil
end

local function selectionForQueue(queueId: string): TeleportPayload.ModeSelection
	local definition = Queues.get(queueId)
	if definition.ModeSelection.Strategy == "Fixed" then
		return { strategy = "Fixed", modeId = definition.ModeSelection.ModeId }
	end
	return { strategy = "Vote", options = table.clone(GameModes.VoteOptions) }
end

local function loadSnapshot(): { [string]: any }
	local activeGate = gate
	local gateSnapshot = if activeGate
		then ArenaReadinessGate.snapshot(activeGate)
		else {
			expectedPlayerCount = 0,
			arrivedPlayerCount = 0,
			readyPlayerCount = 0,
			deadlineAt = 0,
			gateReleased = false,
		}
	return {
		schemaVersion = LOAD_SCHEMA_VERSION,
		expectedPlayerCount = gateSnapshot.expectedPlayerCount,
		arrivedPlayerCount = gateSnapshot.arrivedPlayerCount,
		readyPlayerCount = gateSnapshot.readyPlayerCount,
		deadlineAt = gateSnapshot.deadlineAt,
		gateReleased = gateSnapshot.gateReleased,
		modeOptions = currentModeOptions(),
		queueId = ArenaSessionService.queueId(),
		fixedModeId = if identity then identity.fixedModeId else nil,
		revision = loadRevision,
	}
end

local function publishLoadState()
	loadRevision += 1
	local snapshot = loadSnapshot()
	snapshot.revision = loadRevision
	ensureLoadState().Value = HttpService:JSONEncode(snapshot)
end

local function establishIdentity(queueId: string, modeOptions: { string }, fixedModeId: string?)
	if identity ~= nil then
		return
	end
	identity = { queueId = queueId, modeOptions = table.clone(modeOptions), fixedModeId = fixedModeId }
	publishLoadState()
	for _, listener in table.clone(sessionListeners) do
		local ok, err = pcall(listener, queueId, fixedModeId)
		if not ok then
			warn(`[ArenaSessionService] session listener error: {err}`)
		end
	end
end

local function dispatchReady(player: Player)
	for _, listener in table.clone(readyListeners) do
		local ok, err = pcall(listener, player)
		if not ok then
			warn(`[ArenaSessionService] ready listener error: {err}`)
		end
	end
end

local function dispatchGateReleased(reason: string)
	local snapshot = loadSnapshot()
	local durationSeconds = if snapshot.deadlineAt > 0
		then math.clamp(
			Workspace:GetServerTimeNow() - (snapshot.deadlineAt - READINESS_DEADLINE_SECONDS),
			0,
			READINESS_DEADLINE_SECONDS
		)
		else 0
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isAdmitted(player) then
			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ArenaGateReleased, durationSeconds, {
				reason = reason,
				timedOut = reason == "deadline",
				expectedPlayerCount = snapshot.expectedPlayerCount,
				arrivedPlayerCount = snapshot.arrivedPlayerCount,
				readyPlayerCount = snapshot.readyPlayerCount,
			})
		end
	end
	for _, listener in table.clone(gateReleasedListeners) do
		local ok, err = pcall(listener, reason)
		if not ok then
			warn(`[ArenaSessionService] gate listener error: {err}`)
		end
	end
end

local function evaluateGate(): (boolean, string?)
	local activeGate = gate
	if activeGate == nil then
		return false, nil
	end
	return ArenaReadinessGate.evaluate(activeGate, Workspace:GetServerTimeNow())
end

local function scheduleDeadline()
	local activeGate = gate
	if activeGate == nil or activeGate.kind ~= "Matched" then
		return
	end
	gateGeneration += 1
	local generation = gateGeneration
	local delaySeconds = math.max(activeGate.deadlineAt - Workspace:GetServerTimeNow(), 0)
	task.delay(delaySeconds, function()
		if generation ~= gateGeneration or gate ~= activeGate then
			return
		end
		local released, reason = evaluateGate()
		publishLoadState()
		if released then
			gateGeneration += 1
			dispatchGateReleased(reason or "deadline")
		end
	end)
end

local function createGate(kind: ArenaReadinessGate.Kind, expectedPlayerCount: number)
	gateGeneration += 1
	local deadlineAt = if kind == "Matched" then Workspace:GetServerTimeNow() + READINESS_DEADLINE_SECONDS else 0
	gate = ArenaReadinessGate.new(kind, expectedPlayerCount, deadlineAt)
	scheduleDeadline()
end

local function setAdmission(player: Player, admission: Admission)
	local previous = player:GetAttribute("ArenaAdmission")
	player:SetAttribute("ArenaAdmission", admission)
	if previous ~= admission then
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ArenaArrival, 1, {
			admission = admission,
			queueId = ArenaSessionService.queueId(),
		})
	end
end

local function markReady(player: Player)
	local activeGate = gate
	local lateReady = activeGate ~= nil and activeGate.gateReleased
	if
		activeGate == nil
		or not ArenaSessionService.isAdmitted(player)
		or player:GetAttribute("ArenaClientReady") ~= true
		or not PlayerData.isLoaded(player)
		or not ArenaReadinessGate.markReady(activeGate, player.UserId)
	then
		return
	end

	player:SetAttribute(READY_ATTRIBUTE, true)
	if lateReady then
		local snapshot = ArenaReadinessGate.snapshot(activeGate :: ArenaReadinessGate.State)
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ArenaLateReady, 1, {
			expectedPlayerCount = snapshot.expectedPlayerCount,
			readyPlayerCount = snapshot.readyPlayerCount,
		})
	end
	local released, reason = evaluateGate()
	publishLoadState()
	dispatchReady(player)
	if released then
		gateGeneration += 1
		dispatchGateReleased(reason or "ready")
	end
end

local function addArrival(player: Player, admission: Admission)
	local count = 0
	for _, current in Players:GetPlayers() do
		local currentAdmission = current:GetAttribute("ArenaAdmission")
		if current ~= player and (currentAdmission == "Direct" or currentAdmission == "Matched") then
			count += 1
		end
	end
	if count >= GameModes.QueueCapacity(ArenaSessionService.queueId()) then
		setAdmission(player, "Rejected")
		publishLoadState()
		warn(`[ArenaSessionService] Arena capacity reached for {player.Name}`)
		return
	end
	local activeGate = assert(gate, "[ArenaSessionService] admission requires a readiness gate")
	ArenaReadinessGate.arrive(activeGate, player.UserId)
	setAdmission(player, admission)
	if player:GetAttribute("ArenaRoundEligible") == nil then
		player:SetAttribute("ArenaRoundEligible", true)
	end
	publishLoadState()
	markReady(player)
end

local function reject(player: Player, warning: string)
	setAdmission(player, "Rejected")
	publishLoadState()
	warn(warning)
end

local function directQueueId(): string
	local requested = Debug.StudioQueue
	if RunService:IsStudio() and Queues.isEnabled(requested) then
		return requested
	end
	return Queues.DefaultQueueId
end

local function receive(player: Player)
	local success, joinData = pcall(player.GetJoinData, player)
	if not success then
		reject(player, `[ArenaSessionService] Could not read join data for {player.Name}`)
		return
	end

	local rawPayload = joinData.TeleportData
	if rawPayload == nil then
		if partyByUserId[player.UserId] ~= nil and session ~= nil then
			addArrival(player, "Matched")
			return
		end
		if session ~= nil then
			reject(player, `[ArenaSessionService] Rejected unknown direct arrival in matched session for {player.Name}`)
			return
		end
		if gate == nil then
			local queueId = directQueueId()
			local modeOptions, fixedModeId = resolveSelection(selectionForQueue(queueId))
			if modeOptions == nil then
				reject(player, `[ArenaSessionService] Rejected direct arrival: queue {queueId} has no available mode`)
				return
			end
			createGate("Direct", 1)
			establishIdentity(queueId, modeOptions, fixedModeId)
		elseif gate.kind ~= "Direct" then
			reject(player, `[ArenaSessionService] Rejected mixed direct arrival for {player.Name}`)
			return
		end
		addArrival(player, "Direct")
		return
	end
	if joinData.SourcePlaceId ~= Env.LobbyPlaceId or joinData.SourceGameId ~= game.GameId then
		reject(player, `[ArenaSessionService] Rejected untrusted teleport origin for {player.Name}`)
		return
	end

	local payload, payloadError = TeleportPayload.parse(rawPayload)
	if not payload then
		reject(
			player,
			`[ArenaSessionService] Rejected teleport data for {player.Name}: {payloadError or "invalid_payload"}`
		)
		return
	end

	local modeOptions, fixedModeId = resolveSelection(payload.modeSelection)
	if modeOptions == nil then
		reject(player, `[ArenaSessionService] Rejected session without an available mode for {player.Name}`)
		return
	end

	if session == nil then
		if gate ~= nil then
			reject(player, `[ArenaSessionService] Rejected matched arrival in direct session for {player.Name}`)
			return
		end
		session = {
			matchId = payload.matchId,
			expectedPlayerCount = payload.expectedPlayerCount,
			queueId = payload.queueId,
			modeOptions = modeOptions,
			fixedModeId = fixedModeId,
		}
		createGate("Matched", payload.expectedPlayerCount)
		establishIdentity(payload.queueId, modeOptions, fixedModeId)
	elseif
		session.matchId ~= payload.matchId
		or session.expectedPlayerCount ~= payload.expectedPlayerCount
		or session.queueId ~= payload.queueId
		or session.fixedModeId ~= fixedModeId
		or not ModeOptions.equals(session.modeOptions, modeOptions)
	then
		reject(player, `[ArenaSessionService] Rejected mismatched matchmaking session for {player.Name}`)
		return
	end

	if not registerParty(player, payload.partyId, payload.party) then
		reject(player, `[ArenaSessionService] Rejected inconsistent party context for {player.Name}`)
		return
	end
	addArrival(player, "Matched")
end

local function clientReady(player: Player)
	if not ArenaSessionService.isAdmitted(player) then
		return
	end
	player:SetAttribute("ArenaClientReady", true)
	markReady(player)
end

local LOADING_STAGES = {
	GameLoaded = true,
	ClientReady = true,
}
local PRELOAD_OUTCOMES = {
	Completed = true,
	CompletedWithAssetFailures = true,
	Failed = true,
	Timeout = true,
	CompletedAfterTimeout = true,
}

local function loadingTelemetry(player: Player, payload)
	if payload.kind == "Stage" and LOADING_STAGES[payload.stage] then
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ArenaLoadingStage, payload.durationMs, {
			stage = payload.stage,
		})
	elseif payload.kind == "Preload" and PRELOAD_OUTCOMES[payload.outcome] then
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ArenaPreload, payload.durationMs, {
			outcome = payload.outcome,
		})
	elseif payload.kind == "BallotImpression" then
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ModeVoteImpression, 1, {
			startsAt = payload.startsAt,
		})
	end
end

local function validLoadingTelemetry(_player: Player, payload)
	if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" then
		return false, "invalid_payload"
	end
	if payload.kind == "Stage" then
		return LOADING_STAGES[payload.stage] == true
			and typeof(payload.durationMs) == "number"
			and payload.durationMs >= 0
			and payload.durationMs <= 120000,
			"invalid_stage"
	elseif payload.kind == "Preload" then
		return PRELOAD_OUTCOMES[payload.outcome] == true
			and typeof(payload.durationMs) == "number"
			and payload.durationMs >= 0
			and payload.durationMs <= 120000,
			"invalid_preload"
	elseif payload.kind == "BallotImpression" then
		return typeof(payload.startsAt) == "number" and payload.startsAt > 0 and payload.startsAt < math.huge,
			"invalid_ballot"
	end
	return false, "invalid_kind"
end

function ArenaSessionService.start()
	if started then
		return
	end
	started = true
	ensureLoadState()
	publishLoadState()

	Network.handleProtected("ArenaClientReady", { rateLimit = 4 }, clientReady)
	Network.handleProtected("ReportArenaLoadingEvent", {
		rateLimit = 12,
		validate = validLoadingTelemetry,
	}, loadingTelemetry)
	PlayerData.onLoaded(markReady)

	Players.PlayerAdded:Connect(receive)
	Players.PlayerRemoving:Connect(function(player)
		local activeGate = gate
		if activeGate and ArenaReadinessGate.leave(activeGate, player.UserId) then
			publishLoadState()
		end
	end)
	for _, player in Players:GetPlayers() do
		receive(player)
	end
end

function ArenaSessionService.getSnapshot(): Snapshot?
	if session == nil then
		return nil
	end
	local gateSnapshot = ArenaReadinessGate.snapshot(assert(gate, "matched session requires a readiness gate"))
	return {
		matchId = session.matchId,
		queueId = session.queueId,
		fixedModeId = session.fixedModeId,
		expectedPlayerCount = session.expectedPlayerCount,
		modeOptions = table.clone(session.modeOptions),
		arrivedPlayerCount = gateSnapshot.arrivedPlayerCount,
		readyPlayerCount = gateSnapshot.readyPlayerCount,
		deadlineAt = gateSnapshot.deadlineAt,
		gateReleased = gateSnapshot.gateReleased,
	}
end

function ArenaSessionService.modeOptions(): { string }
	return currentModeOptions()
end

-- The queue this server plays for; the default queue until the first arrival
-- establishes one, so every caller has an answer.
function ArenaSessionService.queueId(): string
	return if identity then identity.queueId else Queues.DefaultQueueId
end

function ArenaSessionService.fixedModeId(): string?
	return if identity then identity.fixedModeId else nil
end

function ArenaSessionService.isEstablished(): boolean
	return identity ~= nil
end

function ArenaSessionService.partyIdFor(player: Player): string?
	return partyByUserId[player.UserId]
end

function ArenaSessionService.partyMemberUserIdsFor(player: Player): { number }
	local partyId = partyByUserId[player.UserId]
	local party = if partyId then partyById[partyId] else nil
	return if party then table.clone(party.memberUserIds) else { player.UserId }
end

function ArenaSessionService.partyPlayersFor(player: Player): { Player }
	local partyId = partyByUserId[player.UserId]
	if partyId == nil then
		return if player.Parent == Players and ArenaSessionService.isAdmitted(player) then { player } else {}
	end
	local result = {}
	for _, candidate in Players:GetPlayers() do
		if partyByUserId[candidate.UserId] == partyId and ArenaSessionService.isAdmitted(candidate) then
			table.insert(result, candidate)
		end
	end
	table.sort(result, function(a, b)
		return a.UserId < b.UserId
	end)
	return result
end

function ArenaSessionService.effectiveLeaderUserIdFor(player: Player): number
	local players = ArenaSessionService.partyPlayersFor(player)
	local partyId = partyByUserId[player.UserId]
	local party = if partyId then partyById[partyId] else nil
	if party then
		for _, candidate in players do
			if candidate.UserId == party.leaderUserId then
				return party.leaderUserId
			end
		end
	end
	return if players[1] then players[1].UserId else player.UserId
end

function ArenaSessionService.isAdmitted(player: Player): boolean
	local admission = player:GetAttribute("ArenaAdmission")
	return admission == "Direct" or admission == "Matched"
end

function ArenaSessionService.isReady(player: Player): boolean
	return gate ~= nil and ArenaReadinessGate.isReady(gate, player.UserId)
end

function ArenaSessionService.isPlayable(player: Player): boolean
	return ArenaSessionService.isAdmitted(player) and ArenaSessionService.isReady(player)
end

function ArenaSessionService.isRoundEligible(player: Player): boolean
	return ArenaSessionService.isPlayable(player) and player:GetAttribute("ArenaRoundEligible") ~= false
end

function ArenaSessionService.setRoundEligible(player: Player, eligible: boolean)
	if not ArenaSessionService.isAdmitted(player) or player:GetAttribute("ArenaRoundEligible") == eligible then
		return
	end
	player:SetAttribute("ArenaRoundEligible", eligible)
	for _, listener in table.clone(roundEligibilityListeners) do
		local ok, err = pcall(listener, player, eligible)
		if not ok then
			warn(`[ArenaSessionService] round eligibility listener error: {err}`)
		end
	end
end

function ArenaSessionService.canOpenVote(): boolean
	return gate ~= nil and gate.gateReleased
end

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

function ArenaSessionService.onReady(listener: (Player) -> ()): () -> ()
	return subscribe(readyListeners, listener)
end

function ArenaSessionService.onRoundEligibilityChanged(listener: (Player, boolean) -> ()): () -> ()
	return subscribe(roundEligibilityListeners, listener)
end

function ArenaSessionService.onGateReleased(listener: (string) -> ()): () -> ()
	return subscribe(gateReleasedListeners, listener)
end

-- Fires once, when the first arrival defines what this server plays; a
-- listener added after that hears it immediately.
function ArenaSessionService.onSessionEstablished(listener: (string, string?) -> ()): () -> ()
	local disconnect = subscribe(sessionListeners, listener)
	if identity then
		listener(identity.queueId, identity.fixedModeId)
	end
	return disconnect
end

return ArenaSessionService
