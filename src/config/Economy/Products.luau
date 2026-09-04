--!strict

-- Developer-product catalog. Preview entries are production-visible but never
-- prompt a purchase; only Active definitions enter the receipt map.

export type CatalogStatus = "Preview" | "Active" | "Hidden"
export type ProductType = "Crate" | "Bonks" | "SeasonPass" | "Bundle" | "Cosmetic"

-- Cosmetic products are how a rotating-shop offer is priced in Robux. One
-- product per cosmetic rather than shared price tiers: a receipt then names
-- exactly what was bought with no second lookup to get wrong, which matters
-- because a receipt is the only record that survives a failed grant.
export type ProductDef = {
	Id: number?,
	Icon: string?,
	CatalogStatus: CatalogStatus,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	Type: ProductType,
	SuggestedRobux: number,
	CrateId: string?,
	BonksAmount: number?,
	SeasonId: string?,
	BundleId: string?,
	ItemId: string?,
}

local Catalog: { [string]: ProductDef } = {
	Bonks500 = {
		Id = 3709429022,
		Icon = "rbxassetid://93880146029014",
		CatalogStatus = "Active",
		DisplayName = "Pocket Stash",
		Description = "A handy boost for your next crate.",
		DisplayOrder = 310,
		Type = "Bonks",
		SuggestedRobux = 49,
		BonksAmount = 500,
	},
	Bonks1100 = {
		Id = 3709429164,
		Icon = "rbxassetid://128078334031314",
		CatalogStatus = "Active",
		DisplayName = "Bonks Stack",
		Description = "A solid stack with a little extra value.",
		DisplayOrder = 320,
		Type = "Bonks",
		SuggestedRobux = 99,
		BonksAmount = 1100,
	},
	Bonks2500 = {
		Id = 3709429259,
		Icon = "rbxassetid://120940829762396",
		CatalogStatus = "Active",
		DisplayName = "Bonks Haul",
		Description = "A bigger haul for several crate opens.",
		DisplayOrder = 330,
		Type = "Bonks",
		SuggestedRobux = 199,
		BonksAmount = 2500,
	},
	Bonks5500 = {
		Id = 3709429349,
		Icon = "rbxassetid://111667665844951",
		CatalogStatus = "Active",
		DisplayName = "Mega Vault",
		Description = "The biggest Bonks bundle and strongest value.",
		DisplayOrder = 340,
		Type = "Bonks",
		SuggestedRobux = 399,
		BonksAmount = 5500,
	},
	DodgeballCrateOpen = {
		Id = 3709429401,
		Icon = "rbxassetid://119117881625478",
		CatalogStatus = "Active",
		DisplayName = "Dodgeballs",
		Description = "Open one Dodgeball Crate directly.",
		DisplayOrder = 210,
		Type = "Crate",
		SuggestedRobux = 39,
		CrateId = "DodgeballCrate",
	},
	HammerCrateOpen = {
		Id = 3709429455,
		Icon = "rbxassetid://134713149561894",
		CatalogStatus = "Active",
		DisplayName = "Hammers",
		Description = "Open one Hammer Crate directly.",
		DisplayOrder = 220,
		Type = "Crate",
		SuggestedRobux = 39,
		CrateId = "HammerCrate",
	},
	EffectsCrateOpen = {
		Id = 3709429563,
		Icon = "rbxassetid://126538865895544",
		CatalogStatus = "Preview",
		DisplayName = "Effects",
		Description = "Open one Effects Crate directly.",
		DisplayOrder = 230,
		Type = "Crate",
		SuggestedRobux = 59,
		CrateId = "EffectsCrate",
	},
	-- One product per bundle. The bundle itself owns its contents in
	-- Config.Bundles; this side owns only the Robux id and price.
	StarterOutfitBundleBuy = {
		Id = nil,
		Icon = "",
		CatalogStatus = "Preview",
		DisplayName = "Starter Outfit Bundle",
		Description = "A complete look, cheaper than buying the pieces.",
		DisplayOrder = 100,
		Type = "Bundle",
		SuggestedRobux = 199,
		BundleId = "StarterOutfitBundle",
	},
	-- One product per season rather than editing SeasonId in place, so receipt
	-- history stays unambiguous about which season was actually bought.
	SeasonPassS1 = {
		Id = 3711055761,
		Icon = "rbxassetid://121533534625743",
		CatalogStatus = "Active",
		DisplayName = "Season 1 Premium Pass",
		Description = "Unlock the premium reward track for Season 1.",
		DisplayOrder = 500,
		Type = "SeasonPass",
		-- Introductory: the GDD targets 799, held back until the track has a
		-- season of proven content behind it.
		SuggestedRobux = 499,
		SeasonId = "S1",
	},
}

local ById: { [number]: ProductDef } = {}

for key, definition in Catalog do
	assert(definition.DisplayOrder % 1 == 0, `developer product "{key}" must define an integer DisplayOrder`)
	assert(definition.SuggestedRobux > 0, `developer product "{key}" must define a positive SuggestedRobux`)
	local icon = definition.Icon
	assert(
		icon == nil or icon == "" or string.match(icon, "^rbxassetid://%d+$") ~= nil,
		`developer product "{key}" Icon must be a Roblox asset id string`
	)
	if definition.CatalogStatus == "Active" then
		assert(definition.Id ~= nil, `active developer product "{key}" must define Id`)
		assert(
			definition.Id > 0 and definition.Id % 1 == 0,
			`developer product "{key}" must define a positive integer Id`
		)
		if definition.Type == "Bonks" then
			assert(
				definition.BonksAmount ~= nil and definition.BonksAmount > 0 and definition.BonksAmount % 1 == 0,
				`bonks product "{key}" must define a positive integer BonksAmount`
			)
		elseif definition.Type == "Crate" then
			assert(
				type(definition.CrateId) == "string" and definition.CrateId ~= "",
				`crate product "{key}" must define CrateId`
			)
		elseif definition.Type == "SeasonPass" then
			assert(
				type(definition.SeasonId) == "string" and definition.SeasonId ~= "",
				`season product "{key}" must define SeasonId`
			)
		elseif definition.Type == "Bundle" then
			assert(
				type(definition.BundleId) == "string" and definition.BundleId ~= "",
				`bundle product "{key}" must define BundleId`
			)
		elseif definition.Type == "Cosmetic" then
			assert(
				type(definition.ItemId) == "string" and definition.ItemId ~= "",
				`cosmetic product "{key}" must define ItemId`
			)
		end
		assert(ById[definition.Id] == nil, `duplicate developer product id {definition.Id}`)
		ById[definition.Id] = definition
	end
end

return {
	Catalog = Catalog,
	ById = ById,
}
