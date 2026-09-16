--!strict

-- Storefront rotation and pricing tunables.

export type FeaturedEntry = {
	kind: string,
	id: string,
}

export type FeaturedConfig = {
	RotationSeconds: number,
	DiscountPercent: number,
	Rotation: { FeaturedEntry },
}

export type BundleConfig = {
	RotationSeconds: number,
	Rotation: { FeaturedEntry },
}

export type RotationConfig = {
	RotationSeconds: number,
	Roles: { RotationRole },
	Categories: { string },
}

export type RotationRole = {
	Id: string,
	Rarities: { string }?,
	Weights: { number }?,
}

-- A/B variant label, stamped on every shop analytics row; empty is the baked config.
local VariantId = ""

local Featured: FeaturedConfig = {
	RotationSeconds = 7 * 24 * 60 * 60,
	DiscountPercent = 15,
	-- Cycled in order, not shuffled. Only Active crates: discounting a Preview crate
	-- would advertise a price nobody can pay.
	Rotation = {
		{ kind = "Crate", id = "DodgeballCrate" },
		{ kind = "Crate", id = "EffectsCrate" },
	},
}

-- May be empty: no bundle featured this period.
local Bundle: BundleConfig = {
	RotationSeconds = 7 * 24 * 60 * 60,
	Rotation = {
		{ kind = "Bundle", id = "StarterOutfitBundle" },
	},
}

-- The per-player rotating shop: temporary offers drawn from these categories
-- only. TrailAssets is omitted until a trail is actually authored -- the draw
-- tolerates an empty category, but listing one states the shop can offer
-- something it cannot.
local Rotation: RotationConfig = {
	RotationSeconds = 24 * 60 * 60,
	Roles = {
		{ Id = "RobuxCommon", Rarities = { "Common" } },
		{ Id = "RobuxPremium", Rarities = { "Rare", "Legendary" }, Weights = { 70, 30 } },
		{ Id = "Bonks" },
	},
	Categories = {
		"BallAssets",
		"HammerAssets",
		"ElimEffectAssets",
		"ImpactEffectAssets",
		"CostumeAssets",
	},
}

assert(#Featured.Rotation > 0, "featured rotation must contain at least one entry")
assert(Featured.RotationSeconds > 0, "featured rotation period must be positive")
assert(
	Featured.DiscountPercent >= 0 and Featured.DiscountPercent < 100,
	"featured discount must be a percentage below 100"
)
assert(Bundle.RotationSeconds > 0, "bundle rotation period must be positive")
assert(Rotation.RotationSeconds > 0, "shop rotation period must be positive")
assert(#Rotation.Roles > 0, "shop rotation must define at least one role")
assert(#Rotation.Categories > 0, "shop rotation must draw from at least one category")

local roleIds: { [string]: boolean } = {}
local rarityRoles: { [string]: number } = {}
for _, role in Rotation.Roles do
	assert(role.Id ~= "" and not roleIds[role.Id], `shop rotation role "{role.Id}" must be unique`)
	roleIds[role.Id] = true
	if role.Id == "Bonks" then
		assert(role.Rarities == nil and role.Weights == nil, "the Bonks role must draw from every eligible rarity")
	else
		assert(role.Rarities ~= nil and #role.Rarities > 0, `shop rotation role "{role.Id}" needs rarities`)
		if role.Weights then
			assert(#role.Weights == #role.Rarities, `shop rotation role "{role.Id}" weights must match its rarities`)
		end
		for index, rarity in role.Rarities do
			assert(table.find({ "Common", "Rare", "Legendary" }, rarity) ~= nil, `unknown offer rarity "{rarity}"`)
			rarityRoles[rarity] = (rarityRoles[rarity] or 0) + 1
			if role.Weights then
				assert(role.Weights[index] > 0, `shop rotation role "{role.Id}" weights must be positive`)
			end
		end
	end
end
assert(roleIds.Bonks, "shop rotation must define one Bonks role")
for _, rarity in { "Common", "Rare", "Legendary" } do
	assert(rarityRoles[rarity] == 1, `shop rotation must define exactly one Robux role for {rarity}`)
end

local RobuxSymbol = "\u{E002}"

return {
	VariantId = VariantId,
	MetadataRefreshSeconds = 300,
	PurchasePollSeconds = 5,
	PurchaseNoticeSeconds = 30,
	RobuxSymbol = RobuxSymbol,
	Featured = Featured,
	Bundle = Bundle,
	Rotation = Rotation,
}
