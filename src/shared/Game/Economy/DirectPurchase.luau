-- Name: DirectPurchase.luau
-- Author: Jack C.
-- Description: Pure rules for buying one named cosmetic outright with Bonks, shared by the server transaction and the client storefront so both agree on price and eligibility.
-- Created: 2026-08-12

--!strict

local DirectPurchase = {}

export type Reason = "unknown_item" | "not_purchasable" | "already_owned" | "insufficient_bonks"

type ItemDef = { Category: string, Rarity: string, AlwaysAvailable: boolean?, [string]: any }
type RarityDef = { DirectBonks: number, [string]: any }

function DirectPurchase.priceFor(
	itemId: string,
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef }
): number?
	local item = items[itemId]
	if item == nil then
		return nil
	end
	if item.AlwaysAvailable == true then
		return nil
	end
	local rarity = rarities[item.Rarity]
	if rarity == nil or rarity.DirectBonks <= 0 then
		return nil
	end
	return rarity.DirectBonks
end

function DirectPurchase.evaluate(
	itemId: string,
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef },
	owned: { [string]: any },
	bonks: number
): (number?, Reason?)
	if items[itemId] == nil then
		return nil, "unknown_item"
	end
	local price = DirectPurchase.priceFor(itemId, items, rarities)
	if price == nil then
		return nil, "not_purchasable"
	end
	if owned[itemId] == true then
		return nil, "already_owned"
	end
	if bonks < price then
		return nil, "insufficient_bonks"
	end
	return price, nil
end

function DirectPurchase.catalog(
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef }
): { { itemId: string, rarity: string, price: number } }
	local entries = {}
	for itemId, item in items do
		local price = DirectPurchase.priceFor(itemId, items, rarities)
		if price ~= nil then
			table.insert(entries, { itemId = itemId, rarity = item.Rarity, price = price })
		end
	end
	table.sort(entries, function(left, right)
		if left.price ~= right.price then
			return left.price < right.price
		end
		return left.itemId < right.itemId
	end)
	return entries
end

return DirectPurchase
