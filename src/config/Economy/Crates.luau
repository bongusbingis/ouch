--!strict

-- Crate definitions. A crate rolls a rarity by weight (Cosmetics Rarities), then
-- uniformly among that rarity's items in the pool. BonksPrice opens with earned
-- Bonks; Robux crates map through Products.ById.
--
-- Pity: opens without the named rarity force it on the next open; the values are
-- disclosed in-store, so changing them changes a published guarantee.
--
-- CatalogStatus: Active (rollable/purchasable), Preview (coming soon, cannot open),
-- Hidden (off the storefront). Unauthored content must be Preview, since the odds
-- model asserts on an empty pool.
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

-- Straight multiple of BonksPrice per open (no volume discount). First entry must be 1.
local OPEN_QUANTITIES = { 1, 5, 10 }

local Cosmetics = require(script.Parent.Parent.Cosmetics.Cosmetics)

-- Derived so a new cosmetic cannot miss its crate; sorted for deterministic odds.
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
