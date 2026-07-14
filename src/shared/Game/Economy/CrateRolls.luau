--!strict

-- Pure crate roll: rarity by weight, then uniform among the pool's items of
-- that rarity. Deterministic given the injected Random, so lune tests can pin
-- distributions and the dupe-refund rule.

local CrateRolls = {}

export type RollResult = {
	itemId: string,
	rarity: string,
	isDupe: boolean,
	cashRefund: number,
}

type ItemDef = { Category: string, Rarity: string, [string]: any }
type RarityDef = { Weight: number, DupeCash: number }

function CrateRolls.roll(
	crate: { ItemPool: { string }, [string]: any },
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef },
	owned: { [string]: any },
	random: Random
): RollResult
	local buckets: { [string]: { string } } = {}
	local rarityOrder: { string } = {}
	local totalWeight = 0

	for _, itemId in crate.ItemPool do
		local item = items[itemId]
		assert(item, `[CrateRolls] unknown item "{itemId}" in crate pool`)
		local rarity = rarities[item.Rarity]
		assert(rarity, `[CrateRolls] unknown rarity "{item.Rarity}" for item "{itemId}"`)
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
	assert(totalWeight > 0, "[CrateRolls] crate pool has no rollable items")
	table.sort(rarityOrder)

	local pick = random:NextNumber() * totalWeight
	local chosenRarity = rarityOrder[#rarityOrder]
	for _, rarityName in rarityOrder do
		pick -= rarities[rarityName].Weight
		if pick <= 0 then
			chosenRarity = rarityName
			break
		end
	end

	local bucket = buckets[chosenRarity]
	table.sort(bucket)
	local itemId = bucket[random:NextInteger(1, #bucket)]
	local isDupe = owned[itemId] == true

	return {
		itemId = itemId,
		rarity = chosenRarity,
		isDupe = isDupe,
		cashRefund = if isDupe then rarities[chosenRarity].DupeCash else 0,
	}
end

return CrateRolls
