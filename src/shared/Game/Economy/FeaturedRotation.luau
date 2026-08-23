--!strict

-- Pure featured-slot schedule, shared by the storefront and the server so the
-- advertised discount is the one actually charged.
--
-- The period index is derived from absolute UTC time rather than any per-player
-- value, so every client and server independently agrees on the current entry
-- without needing to replicate it.

local FeaturedRotation = {}

export type Entry = {
	kind: string,
	id: string,
}

export type Config = {
	RotationSeconds: number,
	DiscountPercent: number,
	Rotation: { Entry },
}

-- Bucketing takes the period length rather than a whole config, because three
-- different schedules now share it: the featured crate, the featured bundle,
-- and the per-player rotating shop. One formula, one place it can be wrong.
function FeaturedRotation.periodIndex(rotationSeconds: number, now: number): number
	return math.floor(now / rotationSeconds)
end

function FeaturedRotation.select(config: Config, now: number): Entry?
	local count = #config.Rotation
	if count == 0 then
		return nil
	end
	return config.Rotation[FeaturedRotation.periodIndex(config.RotationSeconds, now) % count + 1]
end

function FeaturedRotation.nextRotationAt(rotationSeconds: number, now: number): number
	return (FeaturedRotation.periodIndex(rotationSeconds, now) + 1) * rotationSeconds
end

function FeaturedRotation.secondsUntilRotation(rotationSeconds: number, now: number): number
	return math.max(0, FeaturedRotation.nextRotationAt(rotationSeconds, now) - now)
end

-- Rounds in the player's favour, and never below one Bonks so a steep discount
-- cannot make a crate free.
function FeaturedRotation.discountedPrice(basePrice: number, discountPercent: number): number
	return math.max(1, math.floor(basePrice * (100 - discountPercent) / 100))
end

-- The single place both sides answer "what does this crate cost right now".
function FeaturedRotation.priceFor(config: Config, crateId: string, basePrice: number, now: number): number
	local entry = FeaturedRotation.select(config, now)
	if entry == nil or entry.kind ~= "Crate" or entry.id ~= crateId then
		return basePrice
	end
	return FeaturedRotation.discountedPrice(basePrice, config.DiscountPercent)
end

return FeaturedRotation
