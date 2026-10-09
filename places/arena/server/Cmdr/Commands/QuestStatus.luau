-- Description: Cmdr definition for sb-quest-status: shows active daily quest progress for a player.

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
