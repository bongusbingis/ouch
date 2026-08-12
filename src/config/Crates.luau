--!strict

-- Crate definitions. A crate rolls a rarity by weight (Config.Cosmetics
-- Rarities), then uniformly among the pool's items of that rarity.
-- CashPrice = openable with earned Cash; Robux crates map through
-- Config.Products.ById developer products.

-- Pity: opens without the named rarity that force it on the next open. Values
-- are disclosed in the storefront alongside the odds, so changing them changes
-- a published guarantee.
export type CrateDef = {
	DisplayName: string,
	Thumbnail: string,
	CashPrice: number?,
	Pity: { [string]: number }?,
	ItemPool: { string },
}

local Cosmetics = require(script.Parent.Cosmetics)

-- Pools are derived so a new cosmetic cannot be added to the catalog and then
-- silently miss its crate. Sorted for deterministic odds ordering. A crate that
-- needs a curated subset can still declare ItemPool literally.
local function poolByCategory(category: string): { string }
	local pool = {}
	for itemId, item in Cosmetics.Items do
		if item.Category == category then
			table.insert(pool, itemId)
		end
	end
	table.sort(pool)
	return pool
end

return {
	BallCrate = {
		DisplayName = "Ball Crate",
		Thumbnail = "",
		CashPrice = 500,
		Pity = { Rare = 5, Legendary = 25 },
		ItemPool = poolByCategory("BallAssets"),
	},
	TrailCrate = {
		DisplayName = "Trail Crate",
		Thumbnail = "",
		CashPrice = 1000,
		Pity = { Rare = 5, Legendary = 25 },
		ItemPool = poolByCategory("TrailAssets"),
	},
} :: { [string]: CrateDef }
