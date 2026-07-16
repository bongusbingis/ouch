--!strict

return {
	Name = "sb-match-restart",
	Description = "Restarts the match, optionally with a specific mode and map.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "modeId",
			Name = "mode",
			Description = "Mode to use. Omit to keep the current mode.",
			Optional = true,
		},
		{
			Type = "mapId",
			Name = "map",
			Description = "Map to use. Omit for normal map selection.",
			Optional = true,
		},
	},
}
