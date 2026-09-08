-- Description: Pure projection of profile ownership and equips into the ordered inventory categories and entries the locker UI renders.

--!strict

local InventoryModel = {}
local CosmeticsLogic = require(script.Parent.CosmeticsLogic)

export type Entry = {
	id: string,
	itemId: string?,
	category: string,
	displayName: string,
	rarity: string,
	isDefault: boolean,
	sortOrder: number,
	definition: any,
}

type Catalog = {
	Slots: { [string]: boolean }?,
	Defaults: { [string]: any },
	Items: { [string]: any },
	Rarities: { [string]: { DisplayOrder: number } }?,
}

local function sortEntries(entries: { Entry }, catalog: Catalog)
	table.sort(entries, function(left, right)
		if left.category ~= right.category then
			return left.category < right.category
		end
		local leftRarity = catalog.Rarities and catalog.Rarities[left.rarity]
		local rightRarity = catalog.Rarities and catalog.Rarities[right.rarity]
		local leftRarityOrder = if leftRarity then leftRarity.DisplayOrder else math.huge
		local rightRarityOrder = if rightRarity then rightRarity.DisplayOrder else math.huge
		if leftRarityOrder ~= rightRarityOrder then
			return leftRarityOrder < rightRarityOrder
		end
		if left.sortOrder ~= right.sortOrder then
			return left.sortOrder < right.sortOrder
		end
		if left.displayName ~= right.displayName then
			return left.displayName < right.displayName
		end
		return left.id < right.id
	end)
end

function InventoryModel.entries(catalog: Catalog, owned: { [string]: any }, category: string?): { Entry }
	local entries: { Entry } = {}
	for slot, definition in catalog.Defaults or {} do
		if category == nil or slot == category then
			table.insert(entries, {
				id = `Default_{slot}`,
				itemId = nil,
				category = slot,
				displayName = definition.DisplayName,
				rarity = definition.Rarity or "Common",
				isDefault = true,
				sortOrder = definition.SortOrder or 0,
				definition = definition,
			})
		end
	end
	for itemId, definition in catalog.Items or {} do
		if
			(category == nil or definition.Category == category)
			and definition.InventoryVisible ~= false
			and CosmeticsLogic.isOwned(catalog.Items, owned, itemId)
		then
			table.insert(entries, {
				id = itemId,
				itemId = itemId,
				category = definition.Category,
				displayName = definition.DisplayName,
				rarity = definition.Rarity,
				isDefault = false,
				sortOrder = definition.SortOrder or 1000,
				definition = definition,
			})
		end
	end
	sortEntries(entries, catalog)
	return entries
end

function InventoryModel.categories(catalog: Catalog, preferredOrder: { string }): { string }
	local present: { [string]: boolean } = {}
	for category in catalog.Slots or {} do
		present[category] = true
	end
	for category in catalog.Defaults or {} do
		present[category] = true
	end
	for _, item in catalog.Items or {} do
		present[item.Category] = true
	end

	local categories = {}
	for _, category in preferredOrder do
		if present[category] then
			table.insert(categories, category)
			present[category] = nil
		end
	end
	local remaining = {}
	for category in present do
		table.insert(remaining, category)
	end
	table.sort(remaining)
	for _, category in remaining do
		table.insert(categories, category)
	end
	return categories
end

function InventoryModel.find(entries: { Entry }, entryId: string): Entry?
	for _, entry in entries do
		if entry.id == entryId then
			return entry
		end
	end
	return nil
end

function InventoryModel.isEquipped(entry: Entry, equipped: { [string]: any }): boolean
	local itemId = equipped[entry.category]
	if entry.isDefault then
		return itemId == nil or itemId == ""
	end
	return itemId == entry.itemId
end

function InventoryModel.nextEquip(entry: Entry, equipped: { [string]: any }): string?
	if entry.isDefault or InventoryModel.isEquipped(entry, equipped) then
		return nil
	end
	return entry.itemId
end

return InventoryModel
