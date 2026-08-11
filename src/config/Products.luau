--!strict

-- Developer-product catalog. Preview entries are production-visible but never
-- prompt a purchase; only Active definitions enter the receipt map.

export type CatalogStatus = "Preview" | "Active" | "Hidden"
export type ProductType = "Crate" | "Cash" | "SeasonPass"

export type ProductDef = {
	Id: number?,
	CatalogStatus: CatalogStatus,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	Type: ProductType,
	SuggestedRobux: number,
	CrateId: string?,
	CashAmount: number?,
	SeasonId: string?,
}

local Catalog: { [string]: ProductDef } = {
	Cash500 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "500 Cash",
		Description = "A quick top-up for your next crate.",
		DisplayOrder = 310,
		Type = "Cash",
		SuggestedRobux = 49,
		CashAmount = 500,
	},
	Cash1100 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "1,100 Cash",
		Description = "A little extra value for two crate opens.",
		DisplayOrder = 320,
		Type = "Cash",
		SuggestedRobux = 99,
		CashAmount = 1100,
	},
	Cash2500 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "2,500 Cash",
		Description = "A larger top-up with stronger value.",
		DisplayOrder = 330,
		Type = "Cash",
		SuggestedRobux = 199,
		CashAmount = 2500,
	},
	Cash5500 = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "5,500 Cash",
		Description = "The largest evergreen Cash bundle.",
		DisplayOrder = 340,
		Type = "Cash",
		SuggestedRobux = 399,
		CashAmount = 5500,
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
	SeasonalBattlePass = {
		Id = nil,
		CatalogStatus = "Hidden",
		DisplayName = "Seasonal Battle Pass",
		Description = "Unlock the current cosmetic reward track.",
		DisplayOrder = 500,
		Type = "SeasonPass",
		SuggestedRobux = 799,
		SeasonId = nil,
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
		if definition.Type == "Cash" then
			assert(
				definition.CashAmount ~= nil and definition.CashAmount > 0 and definition.CashAmount % 1 == 0,
				`cash product "{key}" must define a positive integer CashAmount`
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
