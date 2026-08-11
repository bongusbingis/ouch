--!strict

-- Builds the single deterministic crate probability model consumed by both
-- rolling and storefront disclosure.

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

return CrateOdds
