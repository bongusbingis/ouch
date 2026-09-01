-- Name: sb-speed-clear.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-speed-clear: clears the Cmdr movement-speed multiplier from players.
-- Created: 2026-07-15

--!strict

return {
	Name = "sb-speed-clear",
	Description = "Clears the Cmdr movement-speed multiplier from players.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players whose Cmdr speed override should clear.",
		},
	},
}
