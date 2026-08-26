-- Name: CrateOdds.luau
-- Author: Jack C.
-- Description: Builds the single deterministic crate probability model used by both rolling and public odds disclosure, allocating displayed percentages so they sum to exactly one hundred.
-- Created: 2026-08-11

--!strict

local CrateOdds = {}

export type Outcome = {
	itemId: string,
	rarity: string,
	probability: number,
}

export type Model = {
	buckets: { [string]: { string } },
	rarityOrder: { string },
	totalWeight: number,
	outcomes: { Outcome },
}

type ItemDef = { Rarity: string, [string]: any }
type RarityDef = { Weight: number, [string]: any }

function CrateOdds.build(
	crate: { ItemPool: { string }, [string]: any },
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef }
): Model
	local buckets: { [string]: { string } } = {}
	local rarityOrder: { string } = {}
	local totalWeight = 0

	for _, itemId in crate.ItemPool do
		local item = items[itemId]
		assert(item, `[CrateOdds] unknown item "{itemId}" in crate pool`)
		local rarity = rarities[item.Rarity]
		assert(rarity, `[CrateOdds] unknown rarity "{item.Rarity}" for item "{itemId}"`)
		if rarity.Weight <= 0 then
			continue
		end
		if buckets[item.Rarity] == nil then
			buckets[item.Rarity] = {}
			table.insert(rarityOrder, item.Rarity)
			totalWeight += rarity.Weight
		end
		table.insert(buckets[item.Rarity], itemId)
	end

	assert(totalWeight > 0, "[CrateOdds] crate pool has no rollable items")
	table.sort(rarityOrder)

	local outcomes: { Outcome } = {}
	for _, rarityName in rarityOrder do
		local bucket = buckets[rarityName]
		table.sort(bucket)
		local probability = rarities[rarityName].Weight / totalWeight / #bucket
		for _, itemId in bucket do
			table.insert(outcomes, {
				itemId = itemId,
				rarity = rarityName,
				probability = probability,
			})
		end
	end

	return {
		buckets = buckets,
		rarityOrder = rarityOrder,
		totalWeight = totalWeight,
		outcomes = outcomes,
	}
end

local function allocate(values: { number }, precision: number): { number }
	local scale = 10 ^ precision
	local totalUnits = math.round(100 * scale)
	local count = #values
	local units = table.create(count)
	local order = table.create(count)
	local assigned = 0

	for index, value in values do
		local exact = value * 100 * scale
		local floored = math.floor(exact)
		units[index] = floored
		order[index] = { index = index, remainder = exact - floored }
		assigned += floored
	end

	table.sort(order, function(left, right)
		if left.remainder ~= right.remainder then
			return left.remainder > right.remainder
		end
		return left.index < right.index
	end)

	for rank = 1, math.clamp(totalUnits - assigned, 0, count) do
		units[order[rank].index] += 1
	end

	local percents = table.create(count)
	for index, unit in units do
		percents[index] = unit / scale
	end
	return percents
end

function CrateOdds.percentByItem(model: Model, precision: number): { [string]: number }
	local values = table.create(#model.outcomes)
	for index, outcome in model.outcomes do
		values[index] = outcome.probability
	end

	local percents = allocate(values, precision)
	local byItem: { [string]: number } = {}
	for index, outcome in model.outcomes do
		byItem[outcome.itemId] = percents[index]
	end
	return byItem
end

function CrateOdds.percentByRarity(
	model: Model,
	rarities: { [string]: RarityDef },
	precision: number
): { [string]: number }
	local values = table.create(#model.rarityOrder)
	for index, rarityName in model.rarityOrder do
		values[index] = rarities[rarityName].Weight / model.totalWeight
	end

	local percents = allocate(values, precision)
	local byRarity: { [string]: number } = {}
	for index, rarityName in model.rarityOrder do
		byRarity[rarityName] = percents[index]
	end
	return byRarity
end

function CrateOdds.formatPercent(percent: number, precision: number): string
	if percent % 1 == 0 then
		return tostring(math.floor(percent))
	end
	return string.format(`%.{precision}f`, percent)
end

return CrateOdds
