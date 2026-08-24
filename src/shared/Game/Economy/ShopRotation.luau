--!strict

-- Deterministic per-player shop rotation. Draws are persisted for the period
-- because purchases change the candidate pool.

local ShopRotation = {}

local MODULUS = 2147483647
local MULTIPLIER = 16807

type ItemDef = { Category: string, AlwaysAvailable: boolean?, [string]: any }

local function step(state: number): number
	return (MULTIPLIER * state) % MODULUS
end

local function seedFor(userId: number, periodIndex: number): number
	local mixed = (math.abs(userId) % MODULUS) * 40503 % MODULUS
	mixed = (mixed + (math.abs(periodIndex) % MODULUS) * 2851) % MODULUS
	local state = mixed % (MODULUS - 1) + 1
	return step(step(state))
end

-- Every item in the given categories that a rotation is allowed to offer.
-- AlwaysAvailable items are excluded: they are free to equip, so offering one
-- for sale would be selling something the player already has.
function ShopRotation.pool(items: { [string]: ItemDef }, categories: { string }): { string }
	local wanted: { [string]: boolean } = {}
	for _, category in categories do
		wanted[category] = true
	end
	local pool = {}
	for itemId, item in items do
		if wanted[item.Category] and item.AlwaysAvailable ~= true then
			table.insert(pool, itemId)
		end
	end
	table.sort(pool)
	return pool
end

-- Draws up to `count` distinct unowned ids. Returns fewer only when the pool
-- holds fewer, and an empty list when there is nothing left to offer -- which
-- is the normal state before any rotation content exists.
function ShopRotation.draw(
	userId: number,
	periodIndex: number,
	pool: { string },
	owned: { [string]: any },
	count: number
): { string }
	local candidates = {}
	for _, itemId in pool do
		if owned[itemId] ~= true then
			table.insert(candidates, itemId)
		end
	end
	-- Sorted before drawing so the caller's pool ordering cannot change the
	-- result. Pool order is already deterministic; this makes it not matter.
	table.sort(candidates)

	local total = #candidates
	local take = math.min(count, total)
	local state = seedFor(userId, periodIndex)
	for index = 1, take do
		state = step(state)
		local pick = index + state % (total - index + 1)
		candidates[index], candidates[pick] = candidates[pick], candidates[index]
	end

	local drawn = table.create(take)
	for index = 1, take do
		drawn[index] = candidates[index]
	end
	return drawn
end

return ShopRotation
