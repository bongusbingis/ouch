-- Name: DataSet.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-data-set: sets a numeric profile field for one or more players.
-- Created: 2026-07-15

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
