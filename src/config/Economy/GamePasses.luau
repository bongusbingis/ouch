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
-- Robux prices come only from client MarketplaceService product information.

export type CatalogStatus = "Preview" | "Active" | "Hidden"

local StoreCatalog = require(script.Parent.Parent.Parent.Shared.Game.Economy.StoreCatalog)

export type Boosts = {
	XpMultiplier: number?,
	BonksMultiplier: number?,
}

export type GamePassDef = {
	Id: number?,
	Icon: string?,
	CatalogStatus: CatalogStatus,
	DisplayName: string,
	Description: string,
	PurchaseMessage: string?,
	DisplayOrder: number,
	Categories: { string },
	EntitlementItemIds: { string },
	Boosts: Boosts?,
}

local Catalog: { [string]: GamePassDef } = {
	Showtime = {
		Id = 1970065084,
		Icon = "rbxassetid://133448903949274",
		CatalogStatus = "Active",
		DisplayName = "Showtime",
		PurchaseMessage = "Your victory emotes are ready. Open Backpack → Emotes to choose your celebration.",
		Description = "Twirl, flex or bounce! Three victory emotes for your result card and every podium you earn.",
		DisplayOrder = 405,
		Categories = { "EmoteAssets" },
		EntitlementItemIds = { "ShowtimeTwirl", "ShowtimeFlex", "ShowtimeBounce" },
	},
	SplatStarter = {
		Id = 1968922292,
		Icon = "rbxassetid://132823050014980",
		CatalogStatus = "Active",
		DisplayName = "Splat Starter Kit",
		Description = "Starlight impact effect. Make every hit sparkle.",
		DisplayOrder = 400,
		Categories = { "ImpactEffectAssets" },
		EntitlementItemIds = { "Starlight" },
	},
	EffectCollection = {
		Id = nil,
		Icon = "rbxassetid://133826079905432",
		CatalogStatus = "Preview",
		DisplayName = "Effect Collection",
		Description = "Prismatic, Galaxy and Starlight impact effects. Make every hit a light show.",
		DisplayOrder = 410,
		Categories = { "ImpactEffectAssets" },
		EntitlementItemIds = { "Prismatic", "Galaxy", "Starlight" },
	},
	DoubleXP = {
		Id = 1952133523,
		Icon = "rbxassetid://94347881059588",
		CatalogStatus = "Active",
		DisplayName = "Double XP",
		Description = "Earn 2x XP from every match, forever.",
		DisplayOrder = 420,
		Categories = {},
		EntitlementItemIds = {},
		Boosts = { XpMultiplier = 2 },
	},
	BonksBoost = {
		Id = 1955640877,
		Icon = "rbxassetid://136145300490466",
		CatalogStatus = "Active",
		DisplayName = "Bonks Boost",
		Description = "Earn 1.5x Bonks from every match, forever.",
		DisplayOrder = 430,
		Categories = {},
		EntitlementItemIds = {},
		Boosts = { BonksMultiplier = 1.5 },
	},
}

for key, definition in Catalog do
	assert(definition.DisplayOrder % 1 == 0, `game pass "{key}" must define an integer DisplayOrder`)
	local icon = definition.Icon
	assert(
		icon == nil or icon == "" or string.match(icon, "^rbxassetid://%d+$") ~= nil,
		`game pass "{key}" Icon must be a Roblox asset id string`
	)
	if definition.Boosts ~= nil then
		local xp = definition.Boosts.XpMultiplier
		local bonks = definition.Boosts.BonksMultiplier
		assert(xp ~= nil or bonks ~= nil, `game pass "{key}" declares an empty Boosts block`)
		assert(xp == nil or xp > 1, `game pass "{key}" XpMultiplier must be greater than 1`)
		assert(bonks == nil or bonks > 1, `game pass "{key}" BonksMultiplier must be greater than 1`)
	end
	if definition.Id ~= nil then
		assert(
			#definition.EntitlementItemIds > 0 or definition.Boosts ~= nil,
			`configured game pass "{key}" must grant entitlements or boosts`
		)
	end
end

local ById, KeyById = StoreCatalog.platformIndex(Catalog)

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
