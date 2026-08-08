--!strict

-- Developer-product catalog. Only enabled definitions with an id enter ById,
-- which is the sole catalog consumed by receipt processing.

export type ProductType = "Crate" | "Cash" | "SeasonPass"

export type ProductDef = {
	Id: number?,
	Enabled: boolean,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	Type: ProductType,
	SuggestedRobux: number?,
	CrateId: string?,
	CashAmount: number?,
	SeasonId: string?,
}

local Catalog: { [string]: ProductDef } = {
	CashPack = {
		Id = nil,
		Enabled = false,
		DisplayName = "Cash Pack",
		Description = "Top up your Cash balance.",
		DisplayOrder = 30,
		Type = "Cash",
		SuggestedRobux = nil,
		CashAmount = nil,
	},
	BallCrateOpen = {
		Id = nil,
		Enabled = false,
		DisplayName = "Ball Crate Open",
		Description = "Open one Ball Crate.",
		DisplayOrder = 40,
		Type = "Crate",
		SuggestedRobux = nil,
		CrateId = "BallCrate",
	},
	TrailCrateOpen = {
		Id = nil,
		Enabled = false,
		DisplayName = "Trail Crate Open",
		Description = "Open one Trail Crate.",
		DisplayOrder = 50,
		Type = "Crate",
		SuggestedRobux = nil,
		CrateId = "TrailCrate",
	},
	SeasonalBattlePass = {
		Id = nil,
		Enabled = false,
		DisplayName = "Seasonal Battle Pass",
		Description = "Unlock the current cosmetic reward track.",
		DisplayOrder = 60,
		Type = "SeasonPass",
		SuggestedRobux = 799,
		SeasonId = nil,
	},
}

local ById: { [number]: ProductDef } = {}

for key, definition in Catalog do
	if definition.Enabled then
		assert(definition.Id ~= nil, `enabled developer product "{key}" must define Id`)
		assert(
			definition.Id > 0 and definition.Id % 1 == 0,
			`developer product "{key}" must define a positive integer Id`
		)
		assert(definition.DisplayOrder % 1 == 0, `developer product "{key}" must define an integer DisplayOrder`)
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
