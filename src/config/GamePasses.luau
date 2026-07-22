--!strict

-- Permanent cosmetic-only pass stubs derived from the GDD monetization tiers.
-- Disabled definitions cannot be sold or interpreted as owned entitlements.

export type GamePassDef = {
	Id: number?,
	Enabled: boolean,
	DisplayName: string,
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
		SuggestedRobuxMin = 150,
		SuggestedRobuxMax = 350,
		Categories = { "HammerAssets" },
		EntitlementItemIds = {},
	},
	DodgeballEffects = {
		Id = nil,
		Enabled = false,
		DisplayName = "Dodgeball Effects",
		SuggestedRobuxMin = 99,
		SuggestedRobuxMax = 250,
		Categories = { "BallAssets", "TrailAssets" },
		EntitlementItemIds = {},
	},
	CharacterCostumes = {
		Id = nil,
		Enabled = false,
		DisplayName = "Character Costumes",
		SuggestedRobuxMin = 250,
		SuggestedRobuxMax = 600,
		Categories = { "CostumeAssets" },
		EntitlementItemIds = {},
	},
	EliminationEmotes = {
		Id = nil,
		Enabled = false,
		DisplayName = "Elimination Emotes",
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
		assert(#definition.EntitlementItemIds > 0, `enabled game pass "{key}" must define entitlements`)
		assert(ById[definition.Id] == nil, `duplicate game pass id {definition.Id}`)
		ById[definition.Id] = definition
	end
end

return {
	Catalog = Catalog,
	ById = ById,
}
