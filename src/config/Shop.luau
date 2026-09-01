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

-- Names the active A/B variant. Empty means the baked configuration. It is
-- overridden live alongside whichever levers an experiment moves, and stamped on
-- every shop analytics row so a result can be attributed to the variant that
-- produced it -- varying prices without labelling them yields numbers nobody can
-- act on.
local VariantId = ""

local Featured: FeaturedConfig = {
	RotationSeconds = 7 * 24 * 60 * 60,
	DiscountPercent = 15,
	-- Cycled in order rather than shuffled: the schedule stays predictable for
	-- planning, and with a short list a shuffle only obscures it.
	--
	-- Only Active crates belong here. Discounting a Preview crate would advertise
	-- a price nobody can pay.
	Rotation = {
		{ kind = "Crate", id = "DodgeballCrate" },
		{ kind = "Crate", id = "EffectsCrate" },
	},
}

-- May be empty. An empty rotation means no bundle is featured this period,
-- which is the honest state before any bundle has content -- better than a
-- placeholder entry pointing at something that cannot be bought.
local Bundle: BundleConfig = {
	RotationSeconds = 7 * 24 * 60 * 60,
	Rotation = {
		{ kind = "Bundle", id = "StarterOutfitBundle" },
	},
}

-- The per-player rotating shop. Offers are temporary, refresh together on this
-- period, and are drawn from these categories only -- crates cover skins and
-- effects, so the rotation is where outfits and emotes are sold individually.
local Rotation: RotationConfig = {
	RotationSeconds = 24 * 60 * 60,
	OfferCount = 3,
	Categories = { "CostumeAssets", "EmoteAssets" },
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
	RobuxSymbol = RobuxSymbol,
	Featured = Featured,
	Bundle = Bundle,
	Rotation = Rotation,
}
