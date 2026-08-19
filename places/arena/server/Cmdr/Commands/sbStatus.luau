--!strict

return {
	Name = "sb-status",
	Aliases = { "splat-status" },
	Description = "Shows match, combat, position, profile, and equipped-cosmetic state for a player.",
	Group = "Splat Brawl | Diagnostics",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player to inspect. Defaults to you.",
			Optional = true,
		},
	},
}
