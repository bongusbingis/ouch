--!strict

-- Permanent cosmetic-only pass stubs derived from the GDD monetization tiers.
-- Disabled definitions cannot be sold or interpreted as owned entitlements.

export type GamePassDef = {
	Id: number?,
	Enabled: boolean,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	SuggestedRobuxMin: number,
	SuggestedRobuxMax: number,
	Categories: { string },
	EntitlementItemIds: { string },
}

local Catalog: { [string]: GamePassDef } = {
	HammerCosmetics = {
		Id = nil,
		Enabled = false,
		DisplayName = "Hammer Cosmetics",
		Description = "A permanent collection of exclusive hammer looks.",
		DisplayOrder = 10,
		SuggestedRobuxMin = 150,
		SuggestedRobuxMax = 350,
		Categories = { "HammerAssets" },
		EntitlementItemIds = {},
	},
	DodgeballEffects = {
		Id = nil,
		Enabled = false,
		DisplayName = "Dodgeball Effects",
		Description = "A permanent collection of ball and trail effects.",
		DisplayOrder = 20,
		SuggestedRobuxMin = 99,
		SuggestedRobuxMax = 250,
		Categories = { "BallAssets", "TrailAssets" },
		EntitlementItemIds = {},
	},
	CharacterCostumes = {
		Id = nil,
		Enabled = false,
		DisplayName = "Character Costumes",
		Description = "A permanent collection of character costumes.",
		DisplayOrder = 30,
		SuggestedRobuxMin = 250,
		SuggestedRobuxMax = 600,
		Categories = { "CostumeAssets" },
		EntitlementItemIds = {},
	},
	EliminationEmotes = {
		Id = nil,
		Enabled = false,
		DisplayName = "Elimination Emotes",
		Description = "A permanent collection of elimination emotes.",
		DisplayOrder = 40,
		SuggestedRobuxMin = 75,
		SuggestedRobuxMax = 150,
		Categories = { "EmoteAssets" },
		EntitlementItemIds = {},
	},
}

local ById: { [number]: GamePassDef } = {}

for key, definition in Catalog do
	if definition.Enabled then
		assert(definition.Id ~= nil, `enabled game pass "{key}" must define Id`)
		assert(definition.Id > 0 and definition.Id % 1 == 0, `game pass "{key}" must define a positive integer Id`)
		assert(definition.DisplayOrder % 1 == 0, `game pass "{key}" must define an integer DisplayOrder`)
		assert(#definition.EntitlementItemIds > 0, `enabled game pass "{key}" must define entitlements`)
		assert(ById[definition.Id] == nil, `duplicate game pass id {definition.Id}`)
		ById[definition.Id] = definition
	end
end

return {
	Catalog = Catalog,
	ById = ById,
}
