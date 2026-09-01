--!strict

-- Crate definitions. A crate rolls a rarity by weight (Config.Cosmetics
-- Rarities), then uniformly among the pool's items of that rarity.
-- BonksPrice = openable with earned Bonks; Robux crates map through
-- Config.Products.ById developer products.

-- Pity: opens without the named rarity that force it on the next open. Values
-- are disclosed in the storefront alongside the odds, so changing them changes
-- a published guarantee.

-- CatalogStatus mirrors Config.Products and Config.GamePasses:
--   Active  -- rollable and purchasable
--   Preview -- merchandised as coming soon; cannot be opened
--   Hidden  -- omitted from the storefront entirely
--
-- A crate whose content has not been authored yet must be Preview. The odds
-- model asserts on an empty pool by design -- shipping a crate that can never
-- drop anything is a bug, not a state to tolerate -- so Preview is how a crate
-- exists in config before it has items.
export type CrateStatus = "Active" | "Preview" | "Hidden"

export type CrateDef = {
	DisplayName: string,
	DisplayOrder: number,
	Thumbnail: string,
	CatalogStatus: CrateStatus,
	BonksPrice: number?,
	Pity: { [string]: number }?,
	OpenQuantities: { number }?,
	ItemPool: { string },
}

-- Bulk opens are charged at a straight multiple of BonksPrice: no volume
-- discount, so the per-open price guarantees asserted in CrateConfig.spec hold
-- for every quantity. The first entry must be 1 -- a crate must always be
-- openable one at a time.
local OPEN_QUANTITIES = { 1, 5, 10 }

local Cosmetics = require(script.Parent.Cosmetics)

-- Pools are derived so a new cosmetic cannot be added to the catalog and then
-- silently miss its crate. Sorted for deterministic odds ordering. A crate that
-- needs a curated subset can still declare ItemPool literally.
local function poolOf(categories: { string }): { string }
	local wanted = {}
	for _, category in categories do
		wanted[category] = true
	end
	local pool = {}
	for itemId, item in Cosmetics.Items do
		if wanted[item.Category] and item.Rarity ~= "Exclusive" then
			table.insert(pool, itemId)
		end
	end
	table.sort(pool)
	return pool
end

local Catalog: { [string]: CrateDef } = {
	DodgeballCrate = {
		DisplayName = "Dodgeball Crate",
		DisplayOrder = 100,
		Thumbnail = "",
		CatalogStatus = "Active",
		BonksPrice = 500,
		Pity = { Rare = 5, Legendary = 25 },
		OpenQuantities = OPEN_QUANTITIES,
		ItemPool = poolOf({ "BallAssets" }),
	},
	HammerCrate = {
		DisplayName = "Hammer Crate",
		DisplayOrder = 200,
		Thumbnail = "",
		CatalogStatus = "Preview",
		BonksPrice = 500,
		Pity = { Rare = 5, Legendary = 25 },
		OpenQuantities = OPEN_QUANTITIES,
		ItemPool = poolOf({ "HammerAssets" }),
	},
	-- Trails and elimination effects are separate equip slots but one crate:
	-- they are the same "effects" purchase to a player, and two near-empty
	-- crates would read as padding.
	EffectsCrate = {
		DisplayName = "Effects Crate",
		DisplayOrder = 300,
		Thumbnail = "",
		CatalogStatus = "Active",
		BonksPrice = 750,
		Pity = { Rare = 5, Legendary = 25 },
		OpenQuantities = OPEN_QUANTITIES,
		ItemPool = poolOf({ "TrailAssets", "ElimEffectAssets", "ImpactEffectAssets" }),
	},
}

for crateId, crate in Catalog do
	assert(crate.DisplayOrder % 1 == 0, `crate {crateId} must define an integer DisplayOrder`)
	assert(
		crate.CatalogStatus == "Active" or crate.CatalogStatus == "Preview" or crate.CatalogStatus == "Hidden",
		`crate {crateId} has an unknown CatalogStatus`
	)
	if crate.CatalogStatus == "Active" then
		assert(#crate.ItemPool > 0, `active crate {crateId} has an empty item pool`)
	end
	if crate.BonksPrice ~= nil then
		assert(crate.BonksPrice > 0, `crate {crateId} must have a positive BonksPrice`)
	end
	if crate.OpenQuantities ~= nil then
		assert(#crate.OpenQuantities > 0, `crate {crateId} must offer at least one open quantity`)
		assert(crate.OpenQuantities[1] == 1, `crate {crateId} must offer a single open as its first quantity`)
		local previous = 0
		for _, quantity in crate.OpenQuantities do
			assert(
				quantity % 1 == 0 and quantity > previous,
				`crate {crateId} open quantities must be ascending positive integers`
			)
			previous = quantity
		end
	end
end

return Catalog
