-- Description: Cmdr definition for sb-player-revive: revives eliminated players through the match respawn flow.

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
