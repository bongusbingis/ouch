-- Description: Cmdr definition for sb-cosmetic-equip: equips an owned cosmetic in its configured slot.

--!strict

return {
	Name = "sb-cosmetic-equip",
	Description = "Equips an owned cosmetic in its configured slot.",
	Group = "Splat Brawl | Economy",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players who will equip the cosmetic.",
		},
		{
			Type = "cosmeticId",
			Name = "cosmetic",
			Description = "Cosmetic to equip.",
		},
	},
}
