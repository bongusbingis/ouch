--!strict

-- Vocabulary for AnalyticsService.luau: funnel/event names in one place so
-- the dashboard's naming stays consistent with what code actually sends.

export type EconomyFlowType = "Source" | "Sink"

local Analytics = {
	Funnels = {
		ShopPurchase = "ShopPurchase",
		Matchmaking = "Matchmaking",
		Onboarding = "Onboarding",
	},

	-- The first-session funnel. Step numbers are fixed forever: they are how a
	-- drop-off is read, so a redesign bumps Config.Onboarding.Version rather
	-- than renumbering these. Steps 2-5 line up with OnboardingSteps.Ordered.
	OnboardingFunnelSteps = {
		Started = { step = 1, name = "Started" },
		NormalThrow = { step = 2, name = "NormalThrow" },
		Hammer = { step = 3, name = "Hammer" },
		ChargedThrow = { step = 4, name = "ChargedThrow" },
		Practice = { step = 5, name = "Practice" },
		Completed = { step = 6, name = "Completed" },
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
		ArenaLoadingStage = "ArenaLoadingStage",
		ArenaPreload = "ArenaPreload",
		ArenaGateReleased = "ArenaGateReleased",
		ArenaLateReady = "ArenaLateReady",
		ModeVoteImpression = "ModeVoteImpression",
		TeleportAttempt = "TeleportAttempt",
		TeleportFailed = "TeleportFailed",
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
		-- First-session onboarding. Milestone-only: nothing here is emitted per
		-- frame, per input, or per projectile step.
		OnboardingEligible = "OnboardingEligible",
		OnboardingStarted = "OnboardingStarted",
		OnboardingResumed = "OnboardingResumed",
		OnboardingStepStarted = "OnboardingStepStarted",
		OnboardingStepCompleted = "OnboardingStepCompleted",
		OnboardingCoreComplete = "OnboardingCoreComplete",
		OnboardingCompleted = "OnboardingCompleted",
		OnboardingSkipped = "OnboardingSkipped",
		OnboardingAbandoned = "OnboardingAbandoned",
		OnboardingError = "OnboardingError",
		OnboardingLobbyRevealed = "OnboardingLobbyRevealed",
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
