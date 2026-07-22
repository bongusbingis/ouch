--!strict

-- Developer-product catalog. Only enabled definitions with an id enter ById,
-- which is the sole catalog consumed by receipt processing.

export type ProductType = "Crate" | "Cash" | "SeasonPass"

export type ProductDef = {
	Id: number?,
	Enabled: boolean,
	DisplayName: string,
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
		Type = "Cash",
		SuggestedRobux = nil,
		CashAmount = nil,
	},
	BallCrateOpen = {
		Id = nil,
		Enabled = false,
		DisplayName = "Ball Crate Open",
		Type = "Crate",
		SuggestedRobux = nil,
		CrateId = "BallCrate",
	},
	TrailCrateOpen = {
		Id = nil,
		Enabled = false,
		DisplayName = "Trail Crate Open",
		Type = "Crate",
		SuggestedRobux = nil,
		CrateId = "TrailCrate",
	},
	SeasonalBattlePass = {
		Id = nil,
		Enabled = false,
		DisplayName = "Seasonal Battle Pass",
		Type = "SeasonPass",
		SuggestedRobux = 799,
		SeasonId = nil,
	},
}

local ById: { [number]: ProductDef } = {}

for key, definition in Catalog do
	if definition.Enabled then
		assert(definition.Id ~= nil, `enabled developer product "{key}" must define Id`)
		assert(ById[definition.Id] == nil, `duplicate developer product id {definition.Id}`)
		ById[definition.Id] = definition
	end
end

return {
	Catalog = Catalog,
	ById = ById,
}
