-- Name: QuestClaim.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-quest-claim: claims the reward for a completed active quest.
-- Created: 2026-07-15

--!strict

return {
	Name = "sb-quest-claim",
	Description = "Claims the reward for a completed active quest.",
	Group = "Splat Brawl | Quests",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players who will claim the quest reward.",
		},
		{
			Type = "questId",
			Name = "quest",
			Description = "Completed active quest to claim.",
		},
	},
}
