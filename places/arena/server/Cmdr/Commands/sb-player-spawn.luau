-- Name: sb-player-spawn.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-player-spawn: teleports players to valid arena spawns.
-- Created: 2026-07-15

--!strict

return {
	Name = "sb-player-spawn",
	Description = "Teleports players to valid arena spawns.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to move to arena spawns.",
		},
	},
}
