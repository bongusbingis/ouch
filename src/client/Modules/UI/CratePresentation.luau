--!strict

-- Derives truthful crate merchandising copy from the same pools and rarity
-- weights used by the authoritative roll logic.

local CratePresentation = {}

local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Exclusive" }
local RARITY_RANK = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Exclusive = 5,
}

export type Presentation = {
	highlight: string,
	odds: string,
	rarityCount: number,
}

local function percentText(weight: number, totalWeight: number): string
	local percent = weight / totalWeight * 100
	local rounded = math.floor(percent + 0.5)
	if math.abs(percent - rounded) < 0.05 then
		return tostring(rounded)
	end
	return string.format("%.1f", percent)
end

function CratePresentation.forCrate(crate: any, cosmetics: any): Presentation
	local buckets: { [string]: { any } } = {}
	local totalWeight = 0

	for _, itemId in crate.ItemPool do
		local item = cosmetics.Items[itemId]
		assert(item, `[CratePresentation] unknown item "{itemId}" in crate pool`)
		local rarity = cosmetics.Rarities[item.Rarity]
		assert(rarity, `[CratePresentation] unknown rarity "{item.Rarity}" for item "{itemId}"`)
		if rarity.Weight > 0 then
			if buckets[item.Rarity] == nil then
				buckets[item.Rarity] = {}
				totalWeight += rarity.Weight
			end
			table.insert(buckets[item.Rarity], item)
		end
	end

	local rarityNames = {}
	for _, rarityName in RARITY_ORDER do
		if buckets[rarityName] then
			table.insert(rarityNames, rarityName)
		end
	end
	local unknown = {}
	for rarityName in buckets do
		if RARITY_RANK[rarityName] == nil then
			table.insert(unknown, rarityName)
		end
	end
	table.sort(unknown)
	for _, rarityName in unknown do
		table.insert(rarityNames, rarityName)
	end

	if totalWeight <= 0 or #rarityNames == 0 then
		return {
			highlight = `{#crate.ItemPool} COSMETICS`,
			odds = "ODDS UNAVAILABLE",
			rarityCount = 0,
		}
	end

	local oddsParts = {}
	for _, rarityName in rarityNames do
		table.insert(
			oddsParts,
			`{string.upper(rarityName)} {percentText(cosmetics.Rarities[rarityName].Weight, totalWeight)}%`
		)
	end

	local highestRarity = rarityNames[1]
	for _, rarityName in rarityNames do
		if (RARITY_RANK[rarityName] or 0) > (RARITY_RANK[highestRarity] or 0) then
			highestRarity = rarityName
		end
	end
	local highestItems = buckets[highestRarity]
	table.sort(highestItems, function(left, right)
		return left.DisplayName < right.DisplayName
	end)
	local highlight = if highestRarity == "Common"
		then `{#crate.ItemPool} COLOR DROPS  •  {highestItems[1].DisplayName}`
		else `CHASE: {highestItems[1].DisplayName}  •  {string.upper(highestRarity)}`

	return {
		highlight = highlight,
		odds = `ODDS  {table.concat(oddsParts, "  •  ")}`,
		rarityCount = #rarityNames,
	}
end

return CratePresentation
