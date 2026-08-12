return {
	Template = {
		SchemaVersion = 0, -- sentinel; never bump here. Target is DataConfig.SchemaVersion.
		Cash = 2500,
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
		Tutorial = {
			Version = 0,
		},
		Onboarding = {
			FirstJoinAt = 0, -- unix time, stamped once; 0 = not yet stamped
		},
		Season = {
			-- Reset wholesale at rollover. Tier is derived from XP, never stored.
			Id = "",
			XP = 0,
			ClaimedFree = {}, -- { [tostring(tier)]: true }
			ClaimedPremium = {},
		},
		Entitlements = {
			-- Never reset by rollover. Developer products are the only ownership
			-- the platform does not remember for us, so premium lives here.
			PremiumSeasons = {}, -- { [seasonId]: true }
		},
		Receipts = {}, -- { [purchaseId]: unix time } for ProcessReceipt idempotency
	},

	SchemaVersion = 1,

	TutorialVersion = 1,

	ProgressionXP = {
		MatchComplete = 25,
		Win = 100,
		Elim = 20,
		Catch = 15,
	},

	ProgressionCash = {
		MatchComplete = 50,
		Win = 150,
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
