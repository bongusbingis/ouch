-- Description: Cmdr definition for sb-cooldowns-reset: queues a reset of all weapon cooldown and phase state for players.

--!strict

return {
	Name = "sb-cooldowns-reset",
	Description = "Queues a reset of all weapon cooldown and phase state for players.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players whose weapon state should reset.",
		},
	},
}
