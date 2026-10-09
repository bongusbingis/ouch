-- Description: Cmdr definition for sb-crate-open-free: rolls a crate without charging Bonks and fires the normal reveal event.

--!strict

return {
	Name = "sb-crate-open-free",
	Description = "Rolls a crate without charging Bonks and fires the normal reveal event.",
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
