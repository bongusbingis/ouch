--!strict

-- Storefront tunables.
--
-- Two rotations live here and they are deliberately different in kind:
--
--   Featured -- one crate, discounted, on a fixed global schedule. Every player
--     on every server sees the same drop at the same time; a per-player version
--     would make the countdown a lie and break word of mouth.
--   Bundle   -- the featured bundle, also global, on its own clock so the two
--     can be scheduled independently.
--   Rotation -- the per-player rotating shop. This one IS tailored: the offers
--     are drawn from the player's own unowned pool so nobody is shown something
--     they already have.
--
-- The discount is real: the server charges the reduced price through the same
-- shared function the storefront displays.

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
	-- Only Active crates belong here. The hammer and effects crates are Preview
	-- until their content exists, and discounting something that cannot be
	-- opened advertises a price nobody can pay -- add them when they go Active.
	Rotation = {
		{ kind = "Crate", id = "DodgeballCrate" },
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

return {
	VariantId = VariantId,
	Featured = Featured,
	Bundle = Bundle,
	Rotation = Rotation,
}
