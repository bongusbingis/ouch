-- Name: ShopViewModel.luau
-- Author: Jack C.
-- Description: Builds the storefront view model: turns catalog, crate, bundle, pass, and product configuration plus live ownership into the ordered sections and cards the shop UI renders.
-- Created: 2026-08-23

--!strict

local ShopViewModel = {}

export type PreviewItem = {
	itemId: string,
	category: string,
	definition: any,
}

export type OddsEntry = {
	itemId: string,
	displayName: string,
	rarity: string,
	percent: number,
}

export type Card = {
	id: string,
	kind: string,
	displayName: string,
	description: string,
	hintText: string?,
	status: string,
	badge: string?,
	thumbnail: string?,
	bonksPrice: number?,
	originalBonksPrice: number?,
	robuxPrice: number?,
	productId: number?,
	passId: number?,
	itemId: string?,
	crateId: string?,
	bundleId: string?,
	affordable: boolean,
	owned: boolean,
	pending: boolean,
	previewItems: { PreviewItem },
	odds: { OddsEntry }?,
	pity: { [string]: number }?,
	openQuantities: { number }?,
	bonksAvailable: number?,
	definition: any,
}

export type Section = {
	id: string,
	title: string,
	countdownAt: number?,
	cards: { Card },
}

export type Model = {
	status: string,
	bonks: number,
	serverNow: number,
	bundleExpireAt: number?,
	featuredExpireAt: number?,
	hero: { Card },
	sections: { Section },
	byId: { [string]: Card },
}

local function sortedKeys(catalog: { [string]: any }, predicate: ((any) -> boolean)?): { string }
	local keys = {}
	for key, definition in catalog do
		if predicate == nil or predicate(definition) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(left, right)
		local leftDefinition = catalog[left]
		local rightDefinition = catalog[right]
		local leftOrder = leftDefinition.DisplayOrder or math.huge
		local rightOrder = rightDefinition.DisplayOrder or math.huge
		if leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end
		return left < right
	end)
	return keys
end

local function productFor(products: { [string]: any }, field: string, value: string): (string?, any?)
	for _, key in sortedKeys(products) do
		local definition = products[key]
		if definition[field] == value then
			return key, definition
		end
	end
	return nil, nil
end

local function metadataFor(metadata: { [string]: any }, kind: string, id: number?): any?
	if id == nil then
		return nil
	end
	return metadata[`{kind}:{id}`]
end

local function configuredIcon(definition: any): string?
	if definition ~= nil and type(definition.Icon) == "string" and definition.Icon ~= "" then
		return definition.Icon
	end
	return nil
end

local function productPresentation(definition: any, metadata: { [string]: any }): (string, number?)
	if definition == nil or definition.CatalogStatus ~= "Active" or definition.Id == nil then
		return "Preview", nil
	end
	local info = metadataFor(metadata, "Product", definition.Id)
	if info == nil then
		return "Loading", nil
	end
	if info.failed == true or info.isForSale == false or type(info.priceInRobux) ~= "number" then
		return "Unavailable", nil
	end
	return "Active", info.priceInRobux
end

local function previewItem(itemId: string, cosmetics: any): PreviewItem?
	local definition = cosmetics.Items[itemId]
	if definition == nil then
		return nil
	end
	return {
		itemId = itemId,
		category = definition.Category,
		definition = definition,
	}
end

local function representativeCrateItem(crate: any, cosmetics: any): PreviewItem?
	local selectedId = nil
	local selectedOrder = math.huge
	for _, itemId in crate.ItemPool do
		local definition = cosmetics.Items[itemId]
		local rarity = if definition then cosmetics.Rarities[definition.Rarity] else nil
		local order = if rarity then rarity.DisplayOrder else math.huge
		if order < selectedOrder or (order == selectedOrder and (selectedId == nil or itemId < selectedId)) then
			selectedId = itemId
			selectedOrder = order
		end
	end
	return if selectedId then previewItem(selectedId, cosmetics) else nil
end

local function appendCard(model: Model, section: { Card }, card: Card)
	table.insert(section, card)
	model.byId[card.id] = card
end

local function crateCard(args: any, crateId: string, featured: boolean): Card
	local crate = args.crates[crateId]
	local cardId = if featured then `FeaturedCrate:{crateId}` else `Crate:{crateId}`
	local _, product = productFor(args.products, "CrateId", crateId)
	local productStatus, robuxPrice = productPresentation(product, args.metadata)
	local status = crate.CatalogStatus
	local bonksPrice = crate.BonksPrice
	local originalBonksPrice = nil
	if featured and bonksPrice ~= nil then
		originalBonksPrice = bonksPrice
		bonksPrice = args.featuredRotation.priceFor(args.shopConfig.Featured, crateId, bonksPrice, args.serverNow)
	end
	if status == "Active" and bonksPrice == nil and productStatus ~= "Active" then
		status = productStatus
	end
	local representative = representativeCrateItem(crate, args.cosmetics)
	local previews = if representative then { representative } else {}
	local odds = nil
	if crate.CatalogStatus == "Active" then
		local oddsModel = args.crateOdds.build(crate, args.cosmetics.Items, args.cosmetics.Rarities)
		local percents = args.crateOdds.percentByItem(oddsModel, 2)
		odds = {}
		for _, outcome in oddsModel.outcomes do
			local definition = args.cosmetics.Items[outcome.itemId]
			table.insert(odds, {
				itemId = outcome.itemId,
				displayName = definition.DisplayName,
				rarity = outcome.rarity,
				percent = percents[outcome.itemId],
			})
		end
	end
	local hintText = if originalBonksPrice ~= nil and bonksPrice ~= nil
		then `{bonksPrice} BONKS  |  WAS {originalBonksPrice}`
		else if bonksPrice ~= nil
			then `{bonksPrice} BONKS`
			else if robuxPrice ~= nil
				then `{args.shopConfig.RobuxSymbol}{robuxPrice}`
				else "RANDOM COSMETIC REWARD"
	return {
		id = cardId,
		kind = "Crate",
		displayName = crate.DisplayName,
		description = "Open for a random cosmetic. View every possible reward before purchasing.",
		hintText = hintText,
		status = status,
		badge = if featured then "FEATURED" else nil,
		thumbnail = if crate.Thumbnail ~= "" then crate.Thumbnail else configuredIcon(product),
		bonksPrice = bonksPrice,
		originalBonksPrice = if originalBonksPrice ~= bonksPrice then originalBonksPrice else nil,
		robuxPrice = if productStatus == "Active" then robuxPrice else nil,
		productId = if productStatus == "Active" then product.Id else nil,
		passId = nil,
		itemId = nil,
		crateId = crateId,
		bundleId = nil,
		affordable = bonksPrice ~= nil and args.bonks >= bonksPrice,
		owned = false,
		pending = args.pending[`Crate:{crateId}`] == true
			or (product ~= nil and product.Id ~= nil and args.pending[`ProductId:{product.Id}`] == true),
		previewItems = previews,
		odds = odds,
		pity = crate.Pity,
		openQuantities = args.crateBatch.quantitiesFor(crate),
		bonksAvailable = args.bonks,
		definition = crate,
	}
end

local function bundleCard(args: any, bundleId: string): Card?
	local bundle = args.bundles.Catalog[bundleId]
	if bundle == nil or bundle.CatalogStatus == "Hidden" then
		return nil
	end
	local _, product = productFor(args.products, "BundleId", bundleId)
	local productStatus, robuxPrice = productPresentation(product, args.metadata)
	local previews = {}
	local owned = #bundle.ItemIds > 0
	for _, itemId in bundle.ItemIds do
		if args.owned[itemId] ~= true then
			owned = false
		end
		local item = if #previews < 3 then previewItem(itemId, args.cosmetics) else nil
		if item ~= nil then
			table.insert(previews, item)
		end
	end
	local status = if owned
		then "Owned"
		else if bundle.CatalogStatus == "Active" then productStatus else bundle.CatalogStatus
	return {
		id = `Bundle:{bundleId}`,
		kind = "Bundle",
		displayName = bundle.DisplayName,
		description = bundle.Description,
		hintText = "LIMITED WEEKLY COLLECTION",
		status = status,
		badge = "WEEKLY BUNDLE",
		thumbnail = configuredIcon(product),
		bonksPrice = nil,
		originalBonksPrice = nil,
		robuxPrice = robuxPrice,
		productId = if productStatus == "Active" then product.Id else nil,
		passId = nil,
		itemId = nil,
		crateId = nil,
		bundleId = bundleId,
		affordable = true,
		owned = owned,
		pending = product ~= nil and product.Id ~= nil and args.pending[`ProductId:{product.Id}`] == true,
		previewItems = previews,
		odds = nil,
		pity = nil,
		definition = bundle,
	}
end

local function cosmeticCard(args: any, offer: any): Card?
	local definition = args.cosmetics.Items[offer.itemId]
	if definition == nil then
		return nil
	end
	local _, product = productFor(args.products, "ItemId", offer.itemId)
	local productStatus, robuxPrice = productPresentation(product, args.metadata)
	local owned = args.owned[offer.itemId] == true
	local preview = previewItem(offer.itemId, args.cosmetics)
	local status = if owned
		then "Owned"
		else if offer.bonksPrice ~= nil or productStatus == "Active"
			then "Active"
			else if productStatus == "Preview" then "Preview" else "Unavailable"
	return {
		id = `Cosmetic:{offer.itemId}`,
		kind = "Cosmetic",
		displayName = definition.DisplayName,
		description = `A {string.lower(definition.Rarity)} cosmetic available in your rotating shop.`,
		hintText = nil,
		status = status,
		badge = definition.Rarity,
		thumbnail = if definition.Thumbnail ~= "" then definition.Thumbnail else nil,
		bonksPrice = offer.bonksPrice,
		originalBonksPrice = nil,
		robuxPrice = if productStatus == "Active" then robuxPrice else nil,
		productId = if productStatus == "Active" then product.Id else nil,
		passId = nil,
		itemId = offer.itemId,
		crateId = nil,
		bundleId = nil,
		affordable = offer.bonksPrice ~= nil and args.bonks >= offer.bonksPrice,
		owned = owned,
		pending = args.pending[`Cosmetic:{offer.itemId}`] == true
			or (product ~= nil and product.Id ~= nil and args.pending[`ProductId:{product.Id}`] == true),
		previewItems = if preview then { preview } else {},
		odds = nil,
		pity = nil,
		definition = definition,
	}
end

local function productCard(args: any, key: string, definition: any): Card
	local status, robuxPrice = productPresentation(definition, args.metadata)
	local info = metadataFor(args.metadata, "Product", definition.Id)
	local owned = definition.Type == "SeasonPass"
		and definition.SeasonId ~= nil
		and args.premiumSeasons[definition.SeasonId] == true
	return {
		id = `Product:{key}`,
		kind = definition.Type,
		displayName = if status == "Active"
				and info
				and type(info.name) == "string"
			then info.name
			else definition.DisplayName,
		description = definition.Description,
		hintText = if definition.Type == "SeasonPass" then "PREMIUM SEASON REWARDS" else nil,
		status = if owned then "Owned" else status,
		badge = if definition.Type == "SeasonPass" then "SEASON PASS" else nil,
		thumbnail = configuredIcon(definition),
		bonksPrice = nil,
		originalBonksPrice = nil,
		robuxPrice = robuxPrice,
		productId = if status == "Active" then definition.Id else nil,
		passId = nil,
		itemId = nil,
		crateId = definition.CrateId,
		bundleId = definition.BundleId,
		affordable = true,
		owned = owned,
		pending = definition.Id ~= nil and args.pending[`ProductId:{definition.Id}`] == true,
		previewItems = {},
		odds = nil,
		pity = nil,
		definition = definition,
	}
end

local function passCard(args: any, key: string, definition: any): Card
	local info = metadataFor(args.metadata, "GamePass", definition.Id)
	local status = definition.CatalogStatus
	local price = nil
	if status == "Active" then
		if info == nil then
			status = "Loading"
		elseif info.failed == true or info.isForSale == false or type(info.priceInRobux) ~= "number" then
			status = "Unavailable"
		else
			price = info.priceInRobux
		end
	end
	local owned = args.ownedPasses[key] == true
	return {
		id = `GamePass:{key}`,
		kind = "GamePass",
		displayName = if status == "Active"
				and info
				and type(info.name) == "string"
			then info.name
			else definition.DisplayName,
		description = definition.Description,
		status = if owned then "Owned" else status,
		badge = "PERMANENT",
		thumbnail = configuredIcon(definition),
		bonksPrice = nil,
		originalBonksPrice = nil,
		robuxPrice = price,
		productId = nil,
		passId = if definition.CatalogStatus == "Active" then definition.Id else nil,
		itemId = nil,
		crateId = nil,
		bundleId = nil,
		affordable = true,
		owned = owned,
		pending = definition.Id ~= nil and args.pending[`GamePassId:{definition.Id}`] == true,
		previewItems = {},
		odds = nil,
		pity = nil,
		definition = definition,
	}
end

function ShopViewModel.build(options: any): Model
	local shopState = options.shopState
	local economy = options.economyData
	local model: Model = {
		status = options.status or "Loading",
		bonks = if economy then economy.Bonks else 0,
		serverNow = if shopState and shopState.serverNow then shopState.serverNow else options.now,
		bundleExpireAt = if shopState then shopState.bundleExpireAt else nil,
		featuredExpireAt = if shopState then shopState.featuredExpireAt else nil,
		hero = {},
		sections = {},
		byId = {},
	}
	if shopState == nil or economy == nil then
		return model
	end

	local args = table.clone(options)
	args.bonks = economy.Bonks
	args.owned = economy.Cosmetics.Owned
	args.premiumSeasons = if economy.Entitlements then economy.Entitlements.PremiumSeasons else {}
	args.serverNow = model.serverNow
	args.pending = options.pending or {}
	args.metadata = options.metadata or {}
	args.ownedPasses = options.ownedPasses or {}

	if shopState.bundle and shopState.bundle.bundleId then
		local bundle = bundleCard(args, shopState.bundle.bundleId)
		if bundle then
			appendCard(model, model.hero, bundle)
		end
	end
	if shopState.featured and shopState.featured.kind == "Crate" and args.crates[shopState.featured.id] then
		appendCard(model, model.hero, crateCard(args, shopState.featured.id, true))
	end
	table.sort(model.hero, function(left, right)
		local leftPriority = if left.status == "Active" then 0 else 1
		local rightPriority = if right.status == "Active" then 0 else 1
		if leftPriority ~= rightPriority then
			return leftPriority < rightPriority
		end
		return left.id < right.id
	end)

	local rotating: Section = {
		id = "ForYou",
		title = "FOR YOU",
		countdownAt = shopState.offersExpireAt,
		cards = {},
	}
	for _, offer in shopState.offers or {} do
		local card = cosmeticCard(args, offer)
		if card then
			appendCard(model, rotating.cards, card)
		end
	end
	if #rotating.cards > 0 then
		table.insert(model.sections, rotating)
	end

	local crates: Section = { id = "Crates", title = "CRATES", countdownAt = nil, cards = {} }
	for _, crateId in
		sortedKeys(args.crates, function(definition)
			return definition.CatalogStatus ~= "Hidden"
		end)
	do
		appendCard(model, crates.cards, crateCard(args, crateId, false))
	end
	table.insert(model.sections, crates)

	local bonks: Section = { id = "Bonks", title = "BONKS", countdownAt = nil, cards = {} }
	for _, key in
		sortedKeys(args.products, function(definition)
			return definition.CatalogStatus ~= "Hidden" and definition.Type == "Bonks"
		end)
	do
		appendCard(model, bonks.cards, productCard(args, key, args.products[key]))
	end
	table.insert(model.sections, bonks)

	local more: Section = { id = "More", title = "PASSES & MORE", countdownAt = nil, cards = {} }
	for _, key in
		sortedKeys(args.gamePasses.Catalog, function(definition)
			return definition.CatalogStatus ~= "Hidden"
		end)
	do
		appendCard(model, more.cards, passCard(args, key, args.gamePasses.Catalog[key]))
	end
	for _, key in
		sortedKeys(args.products, function(definition)
			return definition.CatalogStatus ~= "Hidden" and definition.Type == "SeasonPass"
		end)
	do
		appendCard(model, more.cards, productCard(args, key, args.products[key]))
	end
	table.insert(model.sections, more)

	return model
end

local function revealEntry(entry: any, cosmetics: any): any
	local definition = cosmetics.Items[entry.itemId]
	return {
		itemId = entry.itemId,
		displayName = if definition then definition.DisplayName else entry.itemId,
		rarity = entry.rarity,
		isDupe = entry.isDupe == true,
		bonksRefund = entry.bonksRefund or 0,
		pityTriggered = entry.pityTriggered,
		preview = if definition then previewItem(entry.itemId, cosmetics) else nil,
	}
end

function ShopViewModel.reveal(result: any, cosmetics: any): any
	local entries = {}
	local totalRefund = 0
	local pityTriggered = nil
	for _, entry in result.results or {} do
		local projected = revealEntry(entry, cosmetics)
		totalRefund += projected.bonksRefund
		pityTriggered = pityTriggered or projected.pityTriggered
		table.insert(entries, projected)
	end
	return {
		openId = result.openId,
		crateId = result.crateId,
		count = #entries,
		results = entries,
		totalRefund = totalRefund,
		pityTriggered = pityTriggered,
	}
end

return ShopViewModel
