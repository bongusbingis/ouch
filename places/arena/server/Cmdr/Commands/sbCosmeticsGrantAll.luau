-- Description: Cmdr definition for sb-cosmetics-grant-all: grants every configured cosmetic to one or more players.

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
