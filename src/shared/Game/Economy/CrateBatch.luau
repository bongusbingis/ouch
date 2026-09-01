-- Name: CrateBatch.luau
-- Author: Jack C.
-- Description: Pure rules for opening several crates in one purchase: which quantities a crate offers, whether a requested quantity is legal, and what a batch of that size costs, shared by the server transaction and the client storefront so both agree.
-- Created: 2026-08-25

--!strict

local CrateBatch = {}

local DEFAULT_QUANTITIES = table.freeze({ 1 })

CrateBatch.HardMaximum = 10

type CrateDef = { OpenQuantities: { number }?, [string]: any }

function CrateBatch.quantitiesFor(crate: CrateDef?): { number }
	if crate == nil then
		return DEFAULT_QUANTITIES
	end
	local declared = crate.OpenQuantities
	if declared == nil or #declared == 0 then
		return DEFAULT_QUANTITIES
	end
	return declared
end

function CrateBatch.isValidQuantity(crate: CrateDef?, count: any): boolean
	if typeof(count) ~= "number" or count ~= count or count % 1 ~= 0 then
		return false
	end
	if count < 1 or count > CrateBatch.HardMaximum then
		return false
	end
	for _, quantity in CrateBatch.quantitiesFor(crate) do
		if quantity == count then
			return true
		end
	end
	return false
end

function CrateBatch.totalPrice(unitPrice: number, count: number): number
	return unitPrice * count
end

function CrateBatch.bestRarity(results: { { rarity: string } }, rarities: { [string]: { Weight: number } }): string?
	local best: string? = nil
	for _, result in results do
		local definition = rarities[result.rarity]
		if definition == nil then
			continue
		end
		if best == nil or definition.Weight < rarities[best].Weight then
			best = result.rarity
		end
	end
	return best
end

return table.freeze(CrateBatch)
