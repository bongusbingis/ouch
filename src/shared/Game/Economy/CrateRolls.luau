--!strict

-- Pure crate roll driven by the shared probability model. Deterministic given
-- the injected Random.

local CrateOdds = require(script.Parent.CrateOdds)

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
	local model = CrateOdds.build(crate, items, rarities)
	local pick = random:NextNumber() * model.totalWeight
	local chosenRarity = model.rarityOrder[#model.rarityOrder]
	for _, rarityName in model.rarityOrder do
		pick -= rarities[rarityName].Weight
		if pick <= 0 then
			chosenRarity = rarityName
			break
		end
	end

	local bucket = model.buckets[chosenRarity]
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
