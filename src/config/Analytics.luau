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
	},

	-- Match Enum.AnalyticsEconomyTransactionType names exactly.
	EconomyTransactionTypes = {
		Shop = "Shop",
		IAP = "IAP",
		Gameplay = "Gameplay",
		TimedReward = "TimedReward",
	},
}

return Analytics
