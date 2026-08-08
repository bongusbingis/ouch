--!strict

-- Produces the deterministic client storefront projection from enabled
-- game-pass and developer-product definitions.

export type OfferKind = "GamePass" | "Product"

export type StoreOffer = {
	key: string,
	id: number,
	kind: OfferKind,
	displayName: string,
	description: string,
	displayOrder: number,
	definition: any,
}

local StoreCatalog = {}

local function appendEnabled(target: { StoreOffer }, catalog: { [string]: any }, kind: OfferKind)
	for key, definition in catalog do
		if definition.Enabled and type(definition.Id) == "number" then
			table.insert(target, {
				key = key,
				id = definition.Id,
				kind = kind,
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
	appendEnabled(offers, gamePassCatalog, "GamePass")
	appendEnabled(offers, productCatalog, "Product")
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
