-- Description: Lobby matchmaking tunables: arena place id, per-queue capacity and mode selection, party bounds, queue and store lifetimes, retry policy, and the memory store namespaces separating Studio from live.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Queues = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Queues"))

local Config = {
	ArenaPlaceId = 121997450145716,
	DefaultQueueId = Queues.DefaultQueueId,
	QueueOrder = Queues.Order,
	Queues = {},

	PartyMinPlayers = 1,
	ReturnQueueWaitSeconds = 20,
	ReturnQueuePollSeconds = 1,
	PartyMaxPlayers = 4,

	PartyRecordLifetime = 600,
	PresenceLifetime = 90,
	PresenceHeartbeatInterval = 30,
	PartyRefreshInterval = 60,
	PartyReconcileInterval = 15,
	StaleMemberSweepInterval = 60,

	QueueRecordLifetime = 180,
	QueueCandidateLimit = 100,
	ClaimLifetime = 30,
	WorkerLeaseLifetime = 10,
	WorkerPollInterval = 2,

	CloudRetryAttempts = 4,
	CloudRetryBaseDelay = 0.25,
	CloudRetryMaximumDelay = 2,
	JoinCodeMaxFailures = 5,
	JoinCodeLockoutSeconds = 30,
	BanDataStoreName = "OuchMatchmakingBans_v1",
	BanDataStoreScope = "global",

	MatchRecordLifetime = 900,

	PartyTopicPrefix = "ouch:party:v3:",
	ProtocolVersion = 3,
}

for _, queueId in Queues.Order do
	local definition = Queues.Queues[queueId]
	local selection = definition.ModeSelection
	local modeSelection
	if selection.Strategy == "Fixed" then
		modeSelection = { strategy = "Fixed", modeId = selection.ModeId }
	else
		modeSelection = { strategy = "Vote", options = table.clone(GameModes.VoteOptions) }
	end

	Config.Queues[queueId] = {
		QueueId = queueId,
		Title = definition.Title,
		MatchTargetPlayers = definition.MatchCapacity,
		MatchMinPlayers = definition.MinPlayers,
		MatchMaxWaitSeconds = definition.MaxWaitSeconds,
		MatchPopulationExpansion = definition.PopulationExpansion,
		ModeSelection = modeSelection,
	}
end

Config.MemoryStoreNamespace = RunService:IsStudio() and "OuchDev_v3" or "OuchLive_v3"

return Config
