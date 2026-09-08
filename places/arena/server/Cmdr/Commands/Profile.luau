-- Description: Cmdr definition for sb-profile: shows the loaded profile summary for a player.

--!strict

return {
	Name = "sb-profile",
	Description = "Shows the loaded profile summary for a player.",
	Group = "Splat Brawl | Data",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player to inspect. Defaults to you.",
			Optional = true,
		},
	},
}
