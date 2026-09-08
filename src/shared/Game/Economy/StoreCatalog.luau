-- Description: Produces the deterministic storefront projection, keeping preview offers visible without platform ids and omitting hidden ones.

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

function StoreCatalog.platformIndex(catalog: { [string]: any }): ({ [number]: any }, { [number]: string })
	local byId, keyById = {}, {}
	for key, definition in catalog do
		local id = definition.Id
		assert(definition.CatalogStatus ~= "Active" or id ~= nil, `active offer "{key}" must define Id`)
		if id ~= nil then
			assert(type(id) == "number" and id > 0 and id % 1 == 0, `offer "{key}" requires a positive integer Id`)
			assert(byId[id] == nil, `duplicate platform offer id {id}`)
			byId[id], keyById[id] = definition, key
		end
	end
	return byId, keyById
end

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
