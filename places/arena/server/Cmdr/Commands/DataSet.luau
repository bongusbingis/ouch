-- Description: Cmdr definition for sb-data-set: sets a numeric profile field for one or more players.

--!strict

return {
	Name = "sb-data-set",
	Description = "Sets a numeric profile field for one or more players.",
	Group = "Splat Brawl | Data",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players whose profile field will be set.",
		},
		{
			Type = "profileField",
			Name = "field",
			Description = "Bonks, XP, or progression field.",
		},
		{
			Type = "nonNegativeInteger",
			Name = "value",
			Description = "New field value.",
		},
	},
}
