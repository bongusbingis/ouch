-- Name: sb-speed-scale.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-speed-scale: applies the Cmdr movement-speed multiplier to players.
-- Created: 2026-07-15

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
