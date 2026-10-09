-- Description: Cmdr definition for sb-crate-open-bonks: opens a crate through the normal Bonks purchase path.

--!strict

return {
	Name = "sb-crate-open-bonks",
	Description = "Opens a crate through the normal Bonks purchase path.",
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
			Description = "Bonks crate to purchase.",
		},
	},
}
