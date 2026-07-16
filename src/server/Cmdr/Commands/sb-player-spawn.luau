--!strict

return {
	Name = "sb-player-spawn",
	Description = "Teleports players to valid spawns on the active map.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to move to map spawns.",
		},
	},
}
