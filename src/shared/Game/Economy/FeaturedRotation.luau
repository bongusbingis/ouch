-- Name: FeaturedRotation.luau
-- Author: Jack C.
-- Description: Pure featured-slot schedule derived from absolute time so every client and server agrees on the current entry, its discounted price, and when it rotates.
-- Created: 2026-08-12

--!strict

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

function FeaturedRotation.discountedPrice(basePrice: number, discountPercent: number): number
	return math.max(1, math.floor(basePrice * (100 - discountPercent) / 100))
end

function FeaturedRotation.priceFor(config: Config, crateId: string, basePrice: number, now: number): number
	local entry = FeaturedRotation.select(config, now)
	if entry == nil or entry.kind ~= "Crate" or entry.id ~= crateId then
		return basePrice
	end
	return FeaturedRotation.discountedPrice(basePrice, config.DiscountPercent)
end

return FeaturedRotation
