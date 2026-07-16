--!strict

return {
	Name = "sb-ball-grant",
	Description = "Grants a held ball to players who are not already holding one.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to receive a ball.",
		},
	},
}
