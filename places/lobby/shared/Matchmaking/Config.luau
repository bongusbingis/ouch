-- Description: Lobby matchmaking tunables: arena place id, party bounds, queue and store lifetimes, retry policy, and the memory store namespaces separating Studio from live.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))

local Config = {
	ArenaPlaceId = 121997450145716,
	ModeVoteOptions = table.clone(GameModes.VoteOptions),

	PartyMinPlayers = 1,
	ReturnQueueWaitSeconds = 20,
	ReturnQueuePollSeconds = 1,
	PartyMaxPlayers = 4,
	MatchTargetPlayers = GameModes.MatchCapacity,
	MatchPopulationExpansion = {
		{ AfterSeconds = 0, MinimumPlayers = GameModes.MatchCapacity },
		{ AfterSeconds = 8, MinimumPlayers = 16 },
		{ AfterSeconds = 16, MinimumPlayers = 12 },
		{ AfterSeconds = 24, MinimumPlayers = 8 },
		{ AfterSeconds = 30, MinimumPlayers = 2 },
	},

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

	PartyTopicPrefix = "ouch:party:v2:",
	QueueKey = "AllPlayers",
	WorkerLeaseKey = "AllPlayers",
	ProtocolVersion = 2,
}

Config.MemoryStoreNamespace = RunService:IsStudio() and "OuchDev_v2" or "OuchLive_v2"

return Config
