-- Description: Cmdr definition for sb-quest-set: sets progress on an active daily quest.

--!strict

return {
	Name = "sb-quest-set",
	Description = "Sets progress on an active daily quest.",
	Group = "Splat Brawl | Quests",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players whose quest progress will be set.",
		},
		{
			Type = "questId",
			Name = "quest",
			Description = "Quest definition to update.",
		},
		{
			Type = "nonNegativeInteger",
			Name = "progress",
			Description = "Progress value, clamped to the quest goal.",
		},
	},
}
