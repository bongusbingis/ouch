-- Description: Deterministic per-player shop draw seeded from the player and the period, excluding already-owned items, whose result is persisted because purchases change the candidate pool.

--!strict

local ShopRotation = {}
local CosmeticsLogic = require(script.Parent.CosmeticsLogic)

local MODULUS = 2147483647
local MULTIPLIER = 16807

type ItemDef = { Category: string, Rarity: string, AlwaysAvailable: boolean?, ShopEligible: boolean?, [string]: any }
type Role = { Id: string, Rarities: { string }?, Weights: { number }? }
export type Offer = { ItemId: string, Role: string, Rarity: string }

local function step(state: number): number
	return (MULTIPLIER * state) % MODULUS
end

local function seedFor(userId: number, periodIndex: number): number
	local mixed = (math.abs(userId) % MODULUS) * 40503 % MODULUS
	mixed = (mixed + (math.abs(periodIndex) % MODULUS) * 2851) % MODULUS
	local state = mixed % (MODULUS - 1) + 1
	return step(step(state))
end

function ShopRotation.includes(item: ItemDef, categories: { string }): boolean
	return table.find(categories, item.Category) ~= nil or item.ShopEligible == true
end

function ShopRotation.isEligible(item: ItemDef, categories: { string }): boolean
	return ShopRotation.includes(item, categories)
		and item.ShopEligible ~= false
		and item.AlwaysAvailable ~= true
		and item.InventoryVisible ~= false
		and item.Rarity ~= "Exclusive"
end

function ShopRotation.pool(items: { [string]: ItemDef }, categories: { string }): { string }
	local pool = {}
	for itemId, item in items do
		if ShopRotation.isEligible(item, categories) then
			table.insert(pool, itemId)
		end
	end
	table.sort(pool)
	return pool
end

function ShopRotation.poolByRarity(items: { [string]: ItemDef }, categories: { string }): { [string]: { string } }
	local pools: { [string]: { string } } = {}
	for itemId, item in items do
		if ShopRotation.isEligible(item, categories) then
			local pool = pools[item.Rarity]
			if pool == nil then
				pool = {}
				pools[item.Rarity] = pool
			end
			table.insert(pool, itemId)
		end
	end
	for _, pool in pools do
		table.sort(pool)
	end
	return pools
end

local function weightedRarity(role: Role, state: number): (string?, number)
	local rarities = role.Rarities
	if rarities == nil or #rarities == 0 then
		return nil, state
	end
	if #rarities == 1 then
		return rarities[1], state
	end
	local weights = role.Weights
	if weights == nil then
		return rarities[state % #rarities + 1], step(state)
	end
	local total = 0
	for _, weight in weights do
		total += weight
	end
	state = step(state)
	local roll = state % total + 1
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then
			return rarities[index], state
		end
	end
	return rarities[#rarities], state
end

function ShopRotation.drawRoles(
	userId: number,
	periodIndex: number,
	pools: { [string]: { string } },
	owned: { [string]: any },
	roles: { Role },
	items: { [string]: ItemDef }
): { Offer }
	local state = seedFor(userId, periodIndex)
	local taken: { [string]: boolean } = {}
	local offers: { Offer } = {}
	for _, role in roles do
		local rarity
		rarity, state = weightedRarity(role, state)
		local candidates = {}
		if rarity then
			for _, itemId in pools[rarity] or {} do
				table.insert(candidates, itemId)
			end
		else
			for _, pool in pools do
				for _, itemId in pool do
					table.insert(candidates, itemId)
				end
			end
			table.sort(candidates)
		end
		local available = {}
		for _, itemId in candidates do
			if not taken[itemId] and not CosmeticsLogic.isOwned(items, owned, itemId) then
				table.insert(available, itemId)
			end
		end
		if #available > 0 then
			state = step(state)
			local itemId = available[state % #available + 1]
			local itemRarity = items[itemId].Rarity
			taken[itemId] = true
			table.insert(offers, { ItemId = itemId, Role = role.Id, Rarity = itemRarity })
		end
	end
	return offers
end

function ShopRotation.draw(
	userId: number,
	periodIndex: number,
	pool: { string },
	owned: { [string]: any },
	count: number,
	items: { [string]: ItemDef }?
): { string }
	local candidates = {}
	for _, itemId in pool do
		local isOwned = if items then CosmeticsLogic.isOwned(items, owned, itemId) else owned[itemId] == true
		if not isOwned then
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
