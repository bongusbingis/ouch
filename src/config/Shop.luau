--!strict

-- Storefront tunables. The featured slot rotates on a fixed global schedule so
-- every player on every server sees the same drop at the same time -- a
-- per-player rotation would make the countdown a lie and break word of mouth.
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

local Featured: FeaturedConfig = {
	RotationSeconds = 7 * 24 * 60 * 60,
	DiscountPercent = 15,
	-- Cycled in order rather than shuffled: the schedule stays predictable for
	-- planning, and with a short list a shuffle only obscures it.
	Rotation = {
		{ kind = "Crate", id = "TrailCrate" },
		{ kind = "Crate", id = "BallCrate" },
	},
}

assert(#Featured.Rotation > 0, "featured rotation must contain at least one entry")
assert(Featured.RotationSeconds > 0, "featured rotation period must be positive")
assert(
	Featured.DiscountPercent >= 0 and Featured.DiscountPercent < 100,
	"featured discount must be a percentage below 100"
)

return {
	Featured = Featured,
}
