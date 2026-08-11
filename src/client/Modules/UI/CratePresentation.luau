--!strict

-- Derives truthful crate copy and per-outcome numerical probabilities from the
-- same pure model used by the authoritative roll.

local CrateOdds
if game == nil then
	local root = script.Parent.Parent.Parent.Parent.Parent.Parent
	CrateOdds = require(
		root:WaitForChild("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("Game")
			:WaitForChild("Economy")
			:WaitForChild("CrateOdds")
	)
else
	local replicatedStorage = game:GetService("ReplicatedStorage")
	CrateOdds = require(
		replicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateOdds")
	)
end

local CratePresentation = {}

local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Exclusive" }
local RARITY_RANK = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Exclusive = 5,
}

export type OutcomePresentation = {
	itemId: string,
	displayName: string,
	rarity: string,
	probability: number,
	percentText: string,
}

export type Presentation = {
	highlight: string,
	odds: string,
	rarityCount: number,
	outcomes: { OutcomePresentation },
}

local function percentText(probability: number, precision: number): string
	local percent = probability * 100
	local rounded = math.floor(percent + 0.5)
	if math.abs(percent - rounded) < 0.005 then
		return tostring(rounded)
	end
	return string.format(if precision == 1 then "%.1f" else "%.2f", percent)
end

function CratePresentation.forCrate(crate: any, cosmetics: any): Presentation
	local ok, model = pcall(CrateOdds.build, crate, cosmetics.Items, cosmetics.Rarities)
	if not ok then
		return {
			highlight = `{#crate.ItemPool} COSMETICS`,
			odds = "ODDS UNAVAILABLE",
			rarityCount = 0,
			outcomes = {},
		}
	end

	local rarityNames = {}
	for _, rarityName in RARITY_ORDER do
		if model.buckets[rarityName] then
			table.insert(rarityNames, rarityName)
		end
	end
	local unknown = {}
	for rarityName in model.buckets do
		if RARITY_RANK[rarityName] == nil then
			table.insert(unknown, rarityName)
		end
	end
	table.sort(unknown)
	for _, rarityName in unknown do
		table.insert(rarityNames, rarityName)
	end

	local oddsParts = {}
	for _, rarityName in rarityNames do
		table.insert(
			oddsParts,
			`{string.upper(rarityName)} {percentText(cosmetics.Rarities[rarityName].Weight / model.totalWeight, 1)}%`
		)
	end

	local highestRarity = rarityNames[1]
	for _, rarityName in rarityNames do
		if (RARITY_RANK[rarityName] or 0) > (RARITY_RANK[highestRarity] or 0) then
			highestRarity = rarityName
		end
	end
	local highestItems = model.buckets[highestRarity]
	table.sort(highestItems, function(left, right)
		return cosmetics.Items[left].DisplayName < cosmetics.Items[right].DisplayName
	end)
	local highlight = if highestRarity == "Common"
		then `{#crate.ItemPool} COLOR DROPS  |  {cosmetics.Items[highestItems[1]].DisplayName}`
		else `CHASE: {cosmetics.Items[highestItems[1]].DisplayName}  |  {string.upper(highestRarity)}`

	local outcomes: { OutcomePresentation } = {}
	for _, outcome in model.outcomes do
		table.insert(outcomes, {
			itemId = outcome.itemId,
			displayName = cosmetics.Items[outcome.itemId].DisplayName,
			rarity = outcome.rarity,
			probability = outcome.probability,
			percentText = percentText(outcome.probability, 2),
		})
	end
	table.sort(outcomes, function(left, right)
		local leftRank = RARITY_RANK[left.rarity] or 0
		local rightRank = RARITY_RANK[right.rarity] or 0
		if leftRank ~= rightRank then
			return leftRank > rightRank
		end
		return left.displayName < right.displayName
	end)

	return {
		highlight = highlight,
		odds = `ODDS  {table.concat(oddsParts, "  |  ")}`,
		rarityCount = #rarityNames,
		outcomes = outcomes,
	}
end

return CratePresentation
