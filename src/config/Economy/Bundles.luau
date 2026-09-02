--!strict

-- Cosmetic bundles: a named set of items sold as one purchase.
--
-- A bundle owns its contents and how it presents. It deliberately does not own
-- a developer product id -- Config.Products stays the single place a platform id
-- lives, and a Bundle product points back here through BundleId, exactly as
-- crate and season products already do. Two copies of an id is the one thing
-- that turns a pricing mistake into a wrong grant.
--
-- CatalogStatus matches Config.Products: Preview is merchandised as coming soon
-- and can never be bought, which is what lets a bundle exist in config before
-- its cosmetics are authored. An Active bundle must contain something -- the GDD
-- is explicit that a bundle is never sold empty.

local Cosmetics = require(script.Parent.Parent.Cosmetics.Cosmetics)

export type CatalogStatus = "Preview" | "Active" | "Hidden"

export type BundleDef = {
	CatalogStatus: CatalogStatus,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	ItemIds: { string },
}

local Catalog: { [string]: BundleDef } = {
	-- The shape to copy when the first outfit set is authored. ItemIds is empty
	-- because no costume cosmetics exist yet; fill it in, add a Bundle product in
	-- Config.Products naming this key, then flip both to Active.
	StarterOutfitBundle = {
		CatalogStatus = "Preview",
		DisplayName = "Starter Outfit Bundle",
		Description = "A complete look, cheaper than buying the pieces.",
		DisplayOrder = 100,
		ItemIds = {},
	},
}

for key, definition in Catalog do
	assert(definition.DisplayOrder % 1 == 0, `bundle "{key}" must define an integer DisplayOrder`)
	local seen: { [string]: boolean } = {}
	for _, itemId in definition.ItemIds do
		assert(Cosmetics.Items[itemId] ~= nil, `bundle "{key}" references unknown cosmetic "{itemId}"`)
		assert(not seen[itemId], `bundle "{key}" lists "{itemId}" twice`)
		seen[itemId] = true
	end
	if definition.CatalogStatus == "Active" then
		assert(#definition.ItemIds > 0, `active bundle "{key}" must contain at least one cosmetic`)
	end
end

return {
	Catalog = Catalog,
}
