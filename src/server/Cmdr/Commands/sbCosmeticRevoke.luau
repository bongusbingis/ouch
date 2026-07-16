--!strict

return {
	Name = "sb-cosmetic-revoke",
	Description = "Revokes a cosmetic and clears it if equipped.",
	Group = "Splat Brawl | Economy",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players to lose the cosmetic.",
		},
		{
			Type = "cosmeticId",
			Name = "cosmetic",
			Description = "Cosmetic to revoke.",
		},
	},
}
