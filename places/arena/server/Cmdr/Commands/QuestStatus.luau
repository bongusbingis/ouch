--!strict

return {
	Name = "sb-quest-status",
	Description = "Shows active daily quest progress for a player.",
	Group = "Splat Brawl | Quests",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player to inspect. Defaults to you.",
			Optional = true,
		},
	},
}
