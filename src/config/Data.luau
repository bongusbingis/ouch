return {
	Template = {
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
		Receipts = {}, -- { [purchaseId]: unix time } for ProcessReceipt idempotency
	},

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
