local RunService = game:GetService("RunService")

local Config = {
	ArenaPlaceId = 121997450145716,
	DefaultMapKey = "Default",
	DefaultMode = "FFA",
	GameModes = { "FFA", "TDM", "BR" },

	PartyMinPlayers = 1,
	PartyMaxPlayers = 4,
	MatchTargetPlayers = 20,
	MatchMaximumWait = 30,

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

	TeleportRetryAttempts = 5,
	TeleportRetryDelay = 1,
	TeleportFloodedDelay = 15,
	MatchRecordLifetime = 900,

	PartyTopicPrefix = "ouch:party:v1:",
	ProtocolVersion = 1,
}

Config.MemoryStoreNamespace = RunService:IsStudio() and "OuchDev_v1" or "OuchLive_v1"

return table.freeze(Config)
