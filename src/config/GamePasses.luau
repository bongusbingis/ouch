--!strict

-- Permanent cosmetic-only passes. Preview entries merchandise planned offers
-- without exposing a purchase action; Active entries require platform ids and
-- complete entitlements; Hidden entries never enter the storefront.

export type CatalogStatus = "Preview" | "Active" | "Hidden"

export type GamePassDef = {
	Id: number?,
	CatalogStatus: CatalogStatus,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	SuggestedRobux: number,
	Categories: { string },
	EntitlementItemIds: { string },
}

local Catalog: { [string]: GamePassDef } = {
	HammerCosmetics = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Hammer Cosmetics",
		Description = "A permanent collection of exclusive hammer looks.",
		DisplayOrder = 410,
		SuggestedRobux = 249,
		Categories = { "HammerAssets" },
		EntitlementItemIds = {},
	},
	DodgeballEffects = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Dodgeball Effects",
		Description = "Five exclusive trails, permanently unlocked.",
		DisplayOrder = 420,
		SuggestedRobux = 149,
		Categories = { "TrailAssets" },
		EntitlementItemIds = {
			"TrailCelestialPrism",
			"TrailEventHorizon",
			"TrailRoyalNebula",
			"TrailGlitchSpectrum",
			"TrailSeraphicWake",
		},
	},
	CharacterCostumes = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Character Costumes",
		Description = "A permanent collection of character costumes.",
		DisplayOrder = 430,
		SuggestedRobux = 399,
		Categories = { "CostumeAssets" },
		EntitlementItemIds = {},
	},
	EliminationEmotes = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Elimination Emotes",
		Description = "A permanent collection of elimination emotes.",
		DisplayOrder = 440,
		SuggestedRobux = 99,
		Categories = { "EmoteAssets" },
		EntitlementItemIds = {},
	},
}

local ById: { [number]: GamePassDef } = {}

for key, definition in Catalog do
	assert(definition.DisplayOrder % 1 == 0, `game pass "{key}" must define an integer DisplayOrder`)
	assert(definition.SuggestedRobux > 0, `game pass "{key}" must define a positive SuggestedRobux`)
	if definition.CatalogStatus == "Active" then
		assert(definition.Id ~= nil, `active game pass "{key}" must define Id`)
		assert(definition.Id > 0 and definition.Id % 1 == 0, `game pass "{key}" must define a positive integer Id`)
		assert(#definition.EntitlementItemIds > 0, `active game pass "{key}" must define entitlements`)
		assert(ById[definition.Id] == nil, `duplicate game pass id {definition.Id}`)
		ById[definition.Id] = definition
	end
end

return {
	Catalog = Catalog,
	ById = ById,
}
