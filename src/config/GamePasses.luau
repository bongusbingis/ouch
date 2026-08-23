--!strict

-- Permanent passes. Preview entries merchandise planned offers without exposing
-- a purchase action; Active entries require platform ids and a real grant;
-- Hidden entries never enter the storefront.
--
-- Passes grant cosmetics (EntitlementItemIds), progression boosters (Boosts),
-- or both. Boosts change earn rate only -- never combat values -- per the GDD
-- §2 "no competitive advantage" pillar. Ownership is never persisted to the
-- profile: the platform is the source of truth and EntitlementService caches it
-- per session, so a refund cannot strand a permanent flag on a player.
--
-- The ladder is deliberately priced 49 -> 999 so there is an entry point at
-- every wallet size; BrawlersClub is the intended conversion target and is
-- strictly better than the single boosters it bundles.

export type CatalogStatus = "Preview" | "Active" | "Hidden"

export type Boosts = {
	XpMultiplier: number?,
	BonksMultiplier: number?,
}

export type GamePassDef = {
	Id: number?,
	CatalogStatus: CatalogStatus,
	DisplayName: string,
	Description: string,
	DisplayOrder: number,
	SuggestedRobux: number,
	Categories: { string },
	EntitlementItemIds: { string },
	Boosts: Boosts?,
}

local Catalog: { [string]: GamePassDef } = {
	SplatStarter = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Splat Starter Kit",
		Description = "An exclusive effect you cannot get any other way.",
		DisplayOrder = 400,
		SuggestedRobux = 49,
		Categories = { "TrailAssets" },
		EntitlementItemIds = {},
	},
	EffectCollection = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Effect Collection",
		Description = "A permanent collection of exclusive effects. No boosts, pure looks.",
		DisplayOrder = 410,
		SuggestedRobux = 149,
		Categories = { "TrailAssets", "ElimEffectAssets" },
		EntitlementItemIds = {},
	},
	DoubleXP = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Double XP",
		Description = "Earn 2x XP from every match, forever.",
		DisplayOrder = 420,
		SuggestedRobux = 199,
		Categories = {},
		EntitlementItemIds = {},
		Boosts = { XpMultiplier = 2 },
	},
	BonksBoost = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Bonks Boost",
		Description = "Earn 1.5x Bonks from every match, forever.",
		DisplayOrder = 430,
		SuggestedRobux = 249,
		Categories = {},
		EntitlementItemIds = {},
		Boosts = { BonksMultiplier = 1.5 },
	},
	BrawlersClub = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Brawler's Club",
		Description = "2.5x XP, 1.5x Bonks, and club-only effects. The best value in the shop.",
		DisplayOrder = 440,
		SuggestedRobux = 499,
		Categories = { "TrailAssets", "ElimEffectAssets" },
		EntitlementItemIds = {},
		Boosts = { XpMultiplier = 2.5, BonksMultiplier = 1.5 },
	},
	FoundersPack = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Founder's Pack",
		Description = "Everything in Brawler's Club plus a Founder's effect, retired after launch.",
		DisplayOrder = 450,
		SuggestedRobux = 999,
		Categories = { "TrailAssets", "ElimEffectAssets" },
		EntitlementItemIds = {},
		Boosts = { XpMultiplier = 2.5, BonksMultiplier = 1.5 },
	},
	HammerCosmetics = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Hammer Cosmetics",
		Description = "A permanent collection of exclusive hammer looks.",
		DisplayOrder = 460,
		SuggestedRobux = 249,
		Categories = { "HammerAssets" },
		EntitlementItemIds = {},
	},
	CharacterCostumes = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Character Costumes",
		Description = "A permanent collection of character costumes.",
		DisplayOrder = 470,
		SuggestedRobux = 399,
		Categories = { "CostumeAssets" },
		EntitlementItemIds = {},
	},
	EliminationEmotes = {
		Id = nil,
		CatalogStatus = "Preview",
		DisplayName = "Elimination Emotes",
		Description = "A permanent collection of elimination emotes.",
		DisplayOrder = 480,
		SuggestedRobux = 99,
		Categories = { "EmoteAssets" },
		EntitlementItemIds = {},
	},
}

local ById: { [number]: GamePassDef } = {}
local KeyById: { [number]: string } = {}

for key, definition in Catalog do
	assert(definition.DisplayOrder % 1 == 0, `game pass "{key}" must define an integer DisplayOrder`)
	assert(definition.SuggestedRobux > 0, `game pass "{key}" must define a positive SuggestedRobux`)
	if definition.Boosts ~= nil then
		local xp = definition.Boosts.XpMultiplier
		local bonks = definition.Boosts.BonksMultiplier
		assert(xp ~= nil or bonks ~= nil, `game pass "{key}" declares an empty Boosts block`)
		assert(xp == nil or xp > 1, `game pass "{key}" XpMultiplier must be greater than 1`)
		assert(bonks == nil or bonks > 1, `game pass "{key}" BonksMultiplier must be greater than 1`)
	end
	if definition.CatalogStatus == "Active" then
		assert(definition.Id ~= nil, `active game pass "{key}" must define Id`)
		assert(definition.Id > 0 and definition.Id % 1 == 0, `game pass "{key}" must define a positive integer Id`)
		assert(
			#definition.EntitlementItemIds > 0 or definition.Boosts ~= nil,
			`active game pass "{key}" must grant entitlements or boosts`
		)
		assert(ById[definition.Id] == nil, `duplicate game pass id {definition.Id}`)
		ById[definition.Id] = definition
		KeyById[definition.Id] = key
	end
end

-- The one-time offer spotlights an ordinary pass; it never changes its price or
-- what it grants, only how prominently it is merchandised and for how long.
local StarterOffer = {
	PassKey = "SplatStarter",
	WindowSeconds = 72 * 60 * 60,
}

assert(Catalog[StarterOffer.PassKey] ~= nil, `starter offer references unknown game pass "{StarterOffer.PassKey}"`)
assert(StarterOffer.WindowSeconds > 0, "starter offer window must be positive")

return {
	Catalog = Catalog,
	ById = ById,
	KeyById = KeyById,
	StarterOffer = StarterOffer,
}
