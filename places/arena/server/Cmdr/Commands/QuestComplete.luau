-- Description: Cmdr definition for sb-quest-complete: completes an active daily quest without claiming it.

--!strict

return {
	Name = "sb-quest-complete",
	Description = "Completes an active daily quest without claiming it.",
	Group = "Splat Brawl | Quests",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players whose quest will be completed.",
		},
		{
			Type = "questId",
			Name = "quest",
			Description = "Active quest to complete.",
		},
	},
}
