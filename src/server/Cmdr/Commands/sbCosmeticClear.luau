--!strict

return {
	Name = "sb-cosmetic-clear",
	Description = "Clears an equipped cosmetic slot.",
	Group = "Splat Brawl | Economy",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players whose slot will be cleared.",
		},
		{
			Type = "cosmeticSlot",
			Name = "slot",
			Description = "Cosmetic slot to clear.",
		},
	},
}
