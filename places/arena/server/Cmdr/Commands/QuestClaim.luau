-- Description: Cmdr definition for sb-quest-claim: claims the reward for a completed active quest.

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
