-- Name: Profile.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-profile: shows the loaded profile summary for a player.
-- Created: 2026-07-15

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
