-- Name: CrateRolls.luau
-- Author: Jack C.
-- Description: Pure crate roll driven by the shared probability model and an injected random source, including the pity guarantees and the duplicate refund rule.
-- Created: 2026-07-13

--!strict

local CrateOdds = require(script.Parent.CrateOdds)
local CosmeticsLogic = require(script.Parent.CosmeticsLogic)

local CrateRolls = {}

export type PityState = { [string]: number }

export type RollResult = {
	itemId: string,
	rarity: string,
	isDupe: boolean,
	bonksRefund: number,
	pity: PityState,
	pityTriggered: string?,
}

type ItemDef = { Category: string, Rarity: string, [string]: any }
type RarityDef = { Weight: number, DupeBonks: number }
type CrateDef = { ItemPool: { string }, Pity: { [string]: number }?, [string]: any }

function CrateRolls.roll(
	crate: CrateDef,
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef },
	owned: { [string]: any },
	random: Random,
	pity: PityState?
): RollResult
	local model = CrateOdds.build(crate, items, rarities, pity)
	local thresholds = crate.Pity
	local counters: PityState = {}
	if pity then
		for rarityName, count in pity do
			counters[rarityName] = count
		end
	end

	local forced = model.forcedRarity

	local chosenRarity = forced
	if chosenRarity == nil then
		local pick = random:NextNumber() * model.totalWeight
		chosenRarity = model.rarityOrder[#model.rarityOrder]
		for _, rarityName in model.rarityOrder do
			pick -= rarities[rarityName].Weight
			if pick <= 0 then
				chosenRarity = rarityName
				break
			end
		end
	end

	if thresholds then
		local chosenWeight = rarities[chosenRarity].Weight
		for rarityName, _ in thresholds do
			local tracked = rarities[rarityName]
			if tracked ~= nil and chosenWeight <= tracked.Weight then
				counters[rarityName] = 0
			else
				counters[rarityName] = (counters[rarityName] or 0) + 1
			end
		end
	end

	local bucket = model.buckets[chosenRarity]
	local itemId = bucket[random:NextInteger(1, #bucket)]
	local isDupe = CosmeticsLogic.isOwned(items, owned, itemId)

	return {
		itemId = itemId,
		rarity = chosenRarity,
		isDupe = isDupe,
		bonksRefund = if isDupe then rarities[chosenRarity].DupeBonks else 0,
		pity = counters,
		pityTriggered = forced,
	}
end

return CrateRolls
