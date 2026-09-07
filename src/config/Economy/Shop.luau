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
	OfferCount: number,
	Categories: { string },
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

-- The per-player rotating shop: temporary offers drawn from these categories only.
local Rotation: RotationConfig = {
	RotationSeconds = 24 * 60 * 60,
	OfferCount = 3,
	Categories = {
		"BallAssets",
		"HammerAssets",
		"TrailAssets",
		"ElimEffectAssets",
		"ImpactEffectAssets",
		"CostumeAssets",
		"EmoteAssets",
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
assert(
	Rotation.OfferCount > 0 and Rotation.OfferCount % 1 == 0,
	"shop rotation must offer a positive whole number of items"
)
assert(#Rotation.Categories > 0, "shop rotation must draw from at least one category")

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
