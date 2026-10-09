-- Description: Cmdr definition for sb-speed-clear: clears the Cmdr movement-speed multiplier from players.

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
