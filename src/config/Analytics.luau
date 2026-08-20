--!strict

-- Vocabulary for AnalyticsService.luau: funnel/event names in one place so
-- the dashboard's naming stays consistent with what code actually sends.

export type EconomyFlowType = "Source" | "Sink"

local Analytics = {
	Funnels = {
		ShopPurchase = "ShopPurchase",
		Matchmaking = "Matchmaking",
	},

	ShopFunnelSteps = {
		Opened = { step = 1, name = "Opened" },
		Attempted = { step = 2, name = "Attempted" },
		Completed = { step = 3, name = "Completed" },
	},

	-- The lobby's queue-to-arena journey. Drop-off between these steps is the
	-- only way to tell a slow queue from players abandoning it.
	MatchmakingFunnelSteps = {
		Queued = { step = 1, name = "Queued" },
		Matched = { step = 2, name = "Matched" },
		Teleporting = { step = 3, name = "Teleporting" },
	},

	CustomEvents = {
		Elimination = "Elimination",
		BallCaught = "BallCaught",
		MatchCompleted = "MatchCompleted",
		QuestClaimed = "QuestClaimed",
		SeasonTierClaimed = "SeasonTierClaimed",
		CosmeticGranted = "CosmeticGranted",
		CosmeticEquipped = "CosmeticEquipped",
		CratePurchaseFailed = "CratePurchaseFailed",
		SessionEnded = "SessionEnded",
		MatchmakingCancelled = "MatchmakingCancelled",
		MatchmakingTeleportFailed = "MatchmakingTeleportFailed",
		ModeVoteCast = "ModeVoteCast",
		ModeVoteResolved = "ModeVoteResolved",
		ArenaArrival = "ArenaArrival",
		MenuOpened = "MenuOpened",
		ShopSectionViewed = "ShopSectionViewed",
		ShopOfferSelected = "ShopOfferSelected",
		ShopPromptOpened = "ShopPromptOpened",
		ShopPromptClosed = "ShopPromptClosed",
		ShopPurchaseFailed = "ShopPurchaseFailed",
		-- Input-layer telemetry. These exist to answer the questions in
		-- docs/hitreg-audit.md that reading the code cannot.
		InputLatency = "InputLatency",
		CombatSummary = "CombatSummary",
	},

	-- Every custom event and funnel step carries these, stamped centrally so no
	-- call site can forget them and no cohort comparison is missing rows.
	Dimensions = {
		-- Mouse | Touch | Gamepad. The axis every mobile-competitiveness
		-- question is sliced by.
		DeviceClass = "deviceClass",
		-- Default | Variant, from the player's resolved assist config, so an
		-- A/B test is separable without joining against the config service.
		AssistBucket = "assistBucket",
	},

	-- Seconds between round-trip-time samples per player. Latency is the input
	-- to the largest known fairness gap, so it is sampled rather than inferred.
	-- Frequent enough to see a connection degrade, rare enough not to be noise.
	LatencySampleSeconds = 60,

	-- Match Enum.AnalyticsEconomyTransactionType names exactly.
	EconomyTransactionTypes = {
		Shop = "Shop",
		IAP = "IAP",
		Gameplay = "Gameplay",
		TimedReward = "TimedReward",
	},
}

return Analytics
