-- Name: StoreCatalog.luau
-- Author: Jack C.
-- Description: Produces the deterministic storefront projection, keeping preview offers visible without platform ids and omitting hidden ones.
-- Created: 2026-08-08

--!strict

export type OfferKind = "GamePass" | "Product"
export type CatalogStatus = "Preview" | "Active"

export type StoreOffer = {
	key: string,
	id: number?,
	kind: OfferKind,
	status: CatalogStatus,
	displayName: string,
	description: string,
	displayOrder: number,
	definition: any,
}

local StoreCatalog = {}

local function statusFor(definition: any): string
	if definition.CatalogStatus ~= nil then
		return definition.CatalogStatus
	end
	return if definition.Enabled == true then "Active" else "Hidden"
end

local function appendVisible(target: { StoreOffer }, catalog: { [string]: any }, kind: OfferKind)
	for key, definition in catalog do
		local status = statusFor(definition)
		if status ~= "Hidden" then
			table.insert(target, {
				key = key,
				id = if type(definition.Id) == "number" then definition.Id else nil,
				kind = kind,
				status = status,
				displayName = definition.DisplayName,
				description = definition.Description,
				displayOrder = definition.DisplayOrder,
				definition = definition,
			})
		end
	end
end

function StoreCatalog.build(gamePassCatalog: { [string]: any }, productCatalog: { [string]: any }): { StoreOffer }
	local offers: { StoreOffer } = {}
	appendVisible(offers, gamePassCatalog, "GamePass")
	appendVisible(offers, productCatalog, "Product")
	table.sort(offers, function(left, right)
		if left.displayOrder ~= right.displayOrder then
			return left.displayOrder < right.displayOrder
		end
		if left.kind ~= right.kind then
			return left.kind < right.kind
		end
		return left.key < right.key
	end)
	return offers
end

return StoreCatalog
