return {
	Participation = {
		SampleSeconds = 0.5,
		MinimumMovementStuds = 2,
		ActionWindowSeconds = 3,
		MinimumActiveSeconds = 15,
		QualifyingCatches = 3,
		PerOpponent = { Elim = 8, Catch = 8 },
		PerMatch = { Elim = 40, Catch = 24 },
	},
	Persistence = {
		ReceiptSaveTimeoutSeconds = 8,
		SavePollSeconds = 0.1,
		ProgressionRetrySeconds = 5,
		EntitlementRetrySeconds = 5,
		MaxPendingMatchAwards = 64,
		MaxPendingReceipts = 64,
		ReceiptDetailHistory = 64,
		CompletedMatchAwardHistory = 128,
		MaxSeasonArchives = 64,
	},
	Template = {
		Bonks = 1000,
		Level = {
			Points = 0,
		},
		Progression = {
			Elims = 0,
			Deaths = 0,
			Catches = 0,
			Wins = 0,
			Losses = 0,
			MatchesPlayed = 0,
			KDR = 0,
		},
		Cosmetics = {
			Owned = {}, -- { [itemId]: true }
			Equipped = {}, -- { [slot]: itemId }
		},
		Quests = {
			DailyKey = "",
			ResetAt = 0,
			Active = {},
		},
		Crates = {
			Pity = {}, -- { [crateId]: { [rarity]: opens since that rarity last dropped } }
		},
		Shop = {
			-- The rotating shop's drawn offers, stored against the period they
			-- were drawn for. Persisted rather than recomputed because the draw
			-- excludes owned items: buying one offer would otherwise reshuffle
			-- the others on the next recompute.
			Bucket = -1, -- period index; -1 = never drawn
			Offers = {}, -- { itemId }
		},
		Tutorial = {
			Version = 0,
		},
		Onboarding = {
			FirstJoinAt = 0, -- unix time, stamped once; 0 = not yet stamped
			SwipeThrowLearned = false,
			-- First-session training. Status/Checkpoint are written only by
			-- OnboardingService and interpreted by Shared.Game.Onboarding.
			Status = "NotStarted",
			Checkpoint = "Intro",
			Version = 0,
			SkippedAtStep = "",
		},
		DailyReward = {
			Day = 0, -- last claimed day in cycle (1-7); 0 = never claimed
			LastClaimAt = 0, -- unix timestamp; 0 = never
			TotalClaimed = 0,
		},

		Settings = {}, -- { [settingId]: value }; keys are lazily written by SettingsService

		MatchAwards = { Version = 1, Pending = {}, Completed = {} },
		SeasonHistory = {},
		Season = {
			-- Reset wholesale at rollover. Tier is derived from XP, never stored.
			Id = "",
			XP = 0,
			ClaimedFree = {}, -- { [tostring(tier)]: true }
			ClaimedPremium = {},
			CosmeticClaims = {},
		},
		Entitlements = {
			-- Never reset by rollover. Developer products are the only ownership
			-- the platform does not remember for us, so premium lives here.
			PremiumSeasons = {}, -- { [seasonId]: true }
		},
		ReceiptWork = {},
		Receipts = {}, -- Permanent purchase tombstones; recent entries also retain receipt presentation details.
	},

	TutorialVersion = 1,

	ProgressionXP = {
		MatchComplete = 25,
		Win = 100,
		Elim = 20,
		Catch = 15,
	},

	ProgressionBonks = {
		MatchComplete = 75,
		Win = 100,
		Elim = 10,
		Catch = 15,
	},

	Leaderstats = {
		{
			Name = "Wins",
			Type = "IntValue",
			_Build = function(_player, entry)
				return entry.Data.Progression.Wins
			end,
		},
		-- {
		-- 	Name = "CareerElims",
		-- 	Type = "IntValue",
		-- 	_Build = function(_player, entry)
		-- 		return entry.Data.Progression.Elims
		-- 	end,
		-- },
		{
			Name = "Catches",
			Type = "IntValue",
			_Build = function(_player, entry)
				return entry.Data.Progression.Catches
			end,
		},
		{
			Name = "XP",
			Type = "IntValue",
			_Build = function(_player, entry)
				return entry.Data.Level.Points
			end,
		},
	},
}
