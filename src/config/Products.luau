--!strict

-- Developer-product catalog. Preview entries are production-visible but never
-- prompt a purchase; only Active definitions enter the receipt map.

export type CatalogStatus = "Preview" | "Active" | "Hidden"
export type ProductType = "Crate" | "Bonks" | "SeasonPass"

export type ProductDef = {
	Id: number?,
	CatalogStatus: CatalogStatus,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	Type: ProductType,
	SuggestedRobux: number,
	CrateId: string?,
	BonksAmount: number?,
	SeasonId: string?,
}

local Catalog: { [string]: ProductDef } = {
	Bonks500 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Pocket Stash",
		Description = "A handy boost for your next crate.",
		DisplayOrder = 310,
		Type = "Bonks",
		SuggestedRobux = 49,
		BonksAmount = 500,
	},
	Bonks1100 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Bonks Stack",
		Description = "A solid stack with a little extra value.",
		DisplayOrder = 320,
		Type = "Bonks",
		SuggestedRobux = 99,
		BonksAmount = 1100,
	},
	Bonks2500 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Big Haul",
		Description = "A bigger haul for several crate opens.",
		DisplayOrder = 330,
		Type = "Bonks",
		SuggestedRobux = 199,
		BonksAmount = 2500,
	},
	Bonks5500 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Mega Vault",
		Description = "The biggest Bonks bundle and strongest value.",
		DisplayOrder = 340,
		Type = "Bonks",
		SuggestedRobux = 399,
		BonksAmount = 5500,
	},
	BallCrateOpen = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Ball Crate",
		Description = "Open one Ball Crate directly.",
		DisplayOrder = 210,
		Type = "Crate",
		SuggestedRobux = 39,
		CrateId = "BallCrate",
	},
	TrailCrateOpen = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Trail Crate",
		Description = "Open one Trail Crate directly.",
		DisplayOrder = 220,
		Type = "Crate",
		SuggestedRobux = 79,
		CrateId = "TrailCrate",
	},
	-- One product per season rather than editing SeasonId in place, so receipt
	-- history stays unambiguous about which season was actually bought.
	SeasonPassS1 = {
		Id = nil,
		CatalogStatus = "Preview",
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
		end
		assert(ById[definition.Id] == nil, `duplicate developer product id {definition.Id}`)
		ById[definition.Id] = definition
	end
end

return {
	Catalog = Catalog,
	ById = ById,
}
