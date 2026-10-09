-- Description: Cmdr definition for sb-cosmetic-grant: grants a cosmetic to one or more players.

--!strict

return {
	Name = "sb-cosmetic-grant",
	Description = "Grants a cosmetic to one or more players.",
	Group = "Splat Brawl | Economy",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players to receive the cosmetic.",
		},
		{
			Type = "cosmeticId",
			Name = "cosmetic",
			Description = "Cosmetic to grant.",
		},
	},
}
