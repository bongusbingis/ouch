--!strict

return {
	Name = "sb-crate-open-free",
	Description = "Rolls a crate without charging Cash and fires the normal reveal event.",
	Group = "Splat Brawl | Economy",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players who will open the crate.",
		},
		{
			Type = "crateId",
			Name = "crate",
			Description = "Crate to roll.",
		},
	},
}
