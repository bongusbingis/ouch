-- Name: sbCosmeticsGrantAll.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-cosmetics-grant-all: grants every configured cosmetic to one or more players.
-- Created: 2026-07-15

--!strict

return {
	Name = "sb-cosmetics-grant-all",
	Description = "Grants every configured cosmetic to one or more players.",
	Group = "Splat Brawl | Economy",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players to receive all cosmetics.",
		},
	},
}
