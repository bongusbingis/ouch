--!strict

return {
	Name = "sb-crate-open-cash",
	Description = "Opens a crate through the normal Cash purchase path.",
	Group = "Splat Brawl | Economy",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players who will buy and open the crate.",
		},
		{
			Type = "crateId",
			Name = "crate",
			Description = "Cash crate to purchase.",
		},
	},
}
