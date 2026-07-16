--!strict

return {
	Name = "sb-speed-scale",
	Description = "Applies the Cmdr movement-speed multiplier to players.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players whose speed should change.",
		},
		{
			Type = "number",
			Name = "scale",
			Description = "Positive multiplier applied to base walk speed.",
		},
	},
}
