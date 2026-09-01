-- Name: sb-player-revive.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-player-revive: revives eliminated players through the match respawn flow.
-- Created: 2026-07-15

--!strict

return {
	Name = "sb-player-revive",
	Description = "Revives eliminated players through the match respawn flow.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to revive.",
		},
	},
}
