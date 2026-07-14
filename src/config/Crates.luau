--!strict

-- Crate definitions. A crate rolls a rarity by weight (Config.Cosmetics
-- Rarities), then uniformly among the pool's items of that rarity.
-- CashPrice = openable with earned Cash; Robux crates map through
-- Config.Products developer products.

export type CrateDef = {
	DisplayName: string,
	Thumbnail: string,
	CashPrice: number?,
	ItemPool: { string },
}

return {
	BallCrate = {
		DisplayName = "Ball Crate",
		Thumbnail = "",
		CashPrice = 500,
		ItemPool = {
			"BallRed",
			"BallBlue",
			"BallWhite",
			"BallBlack",
			"BallOrange",
			"BallGreen",
			"BallPink",
			"BallPurple",
			"BallYellow",
		},
	},
} :: { [string]: CrateDef }
