--!strict

-- Pure rules for buying one named cosmetic outright with Cash, shared by the
-- server transaction and the client storefront so both agree on price and
-- eligibility. Rarities with DirectCash 0 are grant-only and never purchasable.

local DirectPurchase = {}

export type Reason = "unknown_item" | "not_purchasable" | "already_owned" | "insufficient_cash"

type ItemDef = { Category: string, Rarity: string, [string]: any }
type RarityDef = { DirectCash: number, [string]: any }

function DirectPurchase.priceFor(
	itemId: string,
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef }
): number?
	local item = items[itemId]
	if item == nil then
		return nil
	end
	local rarity = rarities[item.Rarity]
	if rarity == nil or rarity.DirectCash <= 0 then
		return nil
	end
	return rarity.DirectCash
end

function DirectPurchase.evaluate(
	itemId: string,
	items: { [string]: ItemDef },
	rarities: { [string]: RarityDef },
	owned: { [string]: any },
	cash: number
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
	if cash < price then
		return nil, "insufficient_cash"
	end
	return price, nil
end

-- Deterministic catalog for the storefront: every purchasable item, cheapest
-- first, then by id so two clients never disagree on ordering.
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
