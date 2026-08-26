-- Name: ShopRotation.luau
-- Author: Jack C.
-- Description: Deterministic per-player shop draw seeded from the player and the period, excluding already-owned items, whose result is persisted because purchases change the candidate pool.
-- Created: 2026-08-22

--!strict

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
