--!strict

return {
	Name = "sb-data-add",
	Description = "Adds to a numeric profile field for one or more players.",
	Group = "Splat Brawl | Data",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players whose profile field will be changed.",
		},
		{
			Type = "profileField",
			Name = "field",
			Description = "Cash, XP, or progression field.",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Signed amount to add. Values cannot fall below zero.",
		},
	},
}
