--!strict

return {
	Name = "sb-player-eliminate",
	Description = "Applies an authoritative elimination to one or more players.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to eliminate.",
		},
		{
			Type = "player",
			Name = "source",
			Description = "Player credited for the eliminations. Defaults to you.",
			Optional = true,
		},
	},
}
