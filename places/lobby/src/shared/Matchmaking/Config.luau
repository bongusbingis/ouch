local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes"))

local Config = {
	ArenaPlaceId = 121997450145716,
	ModeVoteOptions = table.clone(GameModes.VoteOptions),

	PartyMinPlayers = 1,
	PartyMaxPlayers = 4,
	MatchTargetPlayers = 20,
	MatchPopulationExpansion = {
		{ AfterSeconds = 0, MinimumPlayers = 20 },
		{ AfterSeconds = 8, MinimumPlayers = 16 },
		{ AfterSeconds = 16, MinimumPlayers = 12 },
		{ AfterSeconds = 24, MinimumPlayers = 8 },
		{ AfterSeconds = 30, MinimumPlayers = 1 },
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
	BanDataStoreName = "OuchMatchmakingBans_v1",
	BanDataStoreScope = "global",

	TeleportRetryAttempts = 5,
	TeleportRetryDelay = 1,
	TeleportFloodedDelay = 15,
	MatchRecordLifetime = 900,

	PartyTopicPrefix = "ouch:party:v2:",
	QueueKey = "AllPlayers",
	WorkerLeaseKey = "AllPlayers",
	ProtocolVersion = 2,
}

Config.MemoryStoreNamespace = RunService:IsStudio() and "OuchDev_v2" or "OuchLive_v2"

-- Left unfrozen so Config.LiveConfig may override the matchmaking scalars it
-- declares; every other field is written only here.
return Config
