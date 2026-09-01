-- Name: QuestReset.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-quest-reset: resets daily quest progress and claims for one or more players.
-- Created: 2026-07-15

--!strict

return {
	Name = "sb-quest-reset",
	Description = "Resets daily quest progress and claims for one or more players.",
	Group = "Splat Brawl | Quests",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players whose daily quests will be reset.",
		},
	},
}
