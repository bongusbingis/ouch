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
