--!strict

-- Vocabulary for AnalyticsService.luau: funnel/event names in one place so
-- the dashboard's naming stays consistent with what code actually sends.

export type EconomyFlowType = "Source" | "Sink"

local Analytics = {
	Funnels = {
		ShopPurchase = "ShopPurchase",
	},

	ShopFunnelSteps = {
		Opened = { step = 1, name = "Opened" },
		Attempted = { step = 2, name = "Attempted" },
		Completed = { step = 3, name = "Completed" },
	},

	CustomEvents = {
		Elimination = "Elimination",
		BallCaught = "BallCaught",
		MatchCompleted = "MatchCompleted",
		QuestClaimed = "QuestClaimed",
		CosmeticGranted = "CosmeticGranted",
		CosmeticEquipped = "CosmeticEquipped",
		CratePurchaseFailed = "CratePurchaseFailed",
		SessionEnded = "SessionEnded",
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
