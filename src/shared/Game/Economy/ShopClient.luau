--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GamePasses"))
local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Products"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

export type Snapshot = {
	status: string,
	shopState: any?,
	metadata: { [string]: any },
	ownedPasses: { [string]: boolean },
	pending: { [string]: boolean },
	reveal: any?,
	grant: any?,
}

local ShopClient = {}

local started = false
local refreshGeneration = 0
local lifecycleGeneration = 0
local callbacks: { (Snapshot) -> () } = {}
local connections: { RBXScriptConnection } = {}
local pendingProducts: { [number]: string } = {}
local pendingPasses: { [number]: string } = {}
local loadingPasses: { [string]: boolean } = {}
local seenOpens: { [string]: boolean } = {}
local seenGrants: { [string]: boolean } = {}

local state: Snapshot = {
	status = "Idle",
	shopState = nil,
	metadata = {},
	ownedPasses = {},
	pending = {},
	reveal = nil,
	grant = nil,
}

local function notify()
	for _, callback in callbacks do
		local ok, err = pcall(callback, state)
		if not ok then
			warn(`[ShopClient] subscriber failed: {err}`)
		end
	end
end

local function update(changes: { [string]: any })
	local nextState = table.clone(state)
	for key, value in changes do
		nextState[key] = value
	end
	state = nextState
	notify()
end

local function setPending(key: string, value: boolean)
	local pending = table.clone(state.pending)
	if value then
		pending[key] = true
	else
		pending[key] = nil
	end
	update({ pending = pending })
end

local function acceptReveal(payload: any)
	local openId = tostring(payload.openId or "")
	if openId == "" or seenOpens[openId] then
		return
	end
	seenOpens[openId] = true
	local completedProductId = nil
	local completedKey = nil
	for productId, key in pendingProducts do
		local definition = Products.ById[productId]
		if definition ~= nil and definition.Type == "Crate" and definition.CrateId == payload.crateId then
			completedProductId = productId
			completedKey = key
			break
		end
	end
	if completedProductId and completedKey then
		pendingProducts[completedProductId] = nil
		setPending(completedKey, false)
	end
	update({ reveal = payload })
end

local function acceptGrant(payload: any)
	local grantId = tostring(payload.grantId or "")
	if grantId == "" or seenGrants[grantId] then
		return
	end
	seenGrants[grantId] = true
	local productId = payload.productId
	if type(productId) == "number" then
		local key = pendingProducts[productId]
		if key then
			pendingProducts[productId] = nil
			setPending(key, false)
		end
	end
	local passId = payload.passId
	if type(passId) == "number" then
		local key = pendingPasses[passId]
		if key then
			pendingPasses[passId] = nil
			setPending(key, false)
		end
		local passKey = GamePasses.KeyById[passId]
		if passKey then
			local ownedPasses = table.clone(state.ownedPasses)
			ownedPasses[passKey] = true
			update({ ownedPasses = ownedPasses })
		end
	end
	update({ grant = payload })
end

local function metadataKey(kind: string, id: number): string
	return `{kind}:{id}`
end

local function requestMetadata(kind: string, id: number, infoType: Enum.InfoType)
	local key = metadataKey(kind, id)
	local existing = state.metadata[key]
	if existing ~= nil and existing.failed ~= true then
		return
	end
	local metadata = table.clone(state.metadata)
	metadata[key] = { loading = true }
	update({ metadata = metadata })
	local generation = lifecycleGeneration
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, infoType)
		if not started or generation ~= lifecycleGeneration then
			return
		end
		local nextMetadata = table.clone(state.metadata)
		if ok then
			nextMetadata[key] = {
				name = info.Name,
				priceInRobux = info.PriceInRobux,
				iconImageAssetId = info.IconImageAssetId,
				isForSale = info.IsForSale ~= false,
			}
		else
			nextMetadata[key] = { failed = true }
		end
		update({ metadata = nextMetadata })
	end)
end

local function loadMarketplaceData()
	for _, definition in Products.Catalog do
		if definition.CatalogStatus == "Active" and definition.Id ~= nil then
			requestMetadata("Product", definition.Id, Enum.InfoType.Product)
		end
	end
	for key, definition in GamePasses.Catalog do
		if definition.CatalogStatus == "Active" and definition.Id ~= nil then
			local passKey = key
			local passId = definition.Id
			requestMetadata("GamePass", passId, Enum.InfoType.GamePass)
			if state.ownedPasses[key] ~= nil or loadingPasses[key] then
				continue
			end
			loadingPasses[passKey] = true
			local generation = lifecycleGeneration
			task.spawn(function()
				local ok, owned = pcall(
					MarketplaceService.UserOwnsGamePassAsync,
					MarketplaceService,
					Players.LocalPlayer.UserId,
					passId
				)
				if not started or generation ~= lifecycleGeneration then
					return
				end
				if ok then
					local ownedPasses = table.clone(state.ownedPasses)
					ownedPasses[passKey] = owned == true
					update({ ownedPasses = ownedPasses })
				end
				loadingPasses[passKey] = nil
			end)
		end
	end
end

function ShopClient.start()
	if started then
		return
	end
	started = true
	lifecycleGeneration += 1
	table.insert(
		connections,
		Network.on("ShopStateChanged", function(shopState)
			update({ status = "Ready", shopState = shopState })
		end)
	)
	table.insert(connections, Network.on("CrateOpened", acceptReveal))
	table.insert(connections, Network.on("StorePurchaseGranted", acceptGrant))
	table.insert(
		connections,
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
			if userId ~= Players.LocalPlayer.UserId then
				return
			end
			local key = pendingProducts[productId]
			if key and not purchased then
				pendingProducts[productId] = nil
				setPending(key, false)
			end
		end)
	)
	table.insert(
		connections,
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if player ~= Players.LocalPlayer then
				return
			end
			local key = pendingPasses[passId]
			if key and not purchased then
				pendingPasses[passId] = nil
				setPending(key, false)
			end
		end)
	)
	loadMarketplaceData()
end

function ShopClient.refresh(): (boolean, string?)
	if not started then
		return false, "not_started"
	end
	if state.status == "Refreshing" then
		return false, "busy"
	end
	refreshGeneration += 1
	loadMarketplaceData()
	local generation = refreshGeneration
	update({ status = "Refreshing" })
	local ok, result = pcall(Network.call, "GetShopState")
	if generation ~= refreshGeneration then
		return false, "stale"
	end
	if not ok or type(result) ~= "table" then
		update({ status = "Error" })
		return false, "network_error"
	end
	update({ status = "Ready", shopState = result })
	return true, nil
end

function ShopClient.purchaseCosmetic(_cardId: string, itemId: string): (boolean, string?)
	local pendingKey = `Cosmetic:{itemId}`
	if state.pending[pendingKey] then
		return false, "busy"
	end
	setPending(pendingKey, true)
	local ok, result, reason = pcall(Network.call, "PurchaseCosmetic", itemId)
	setPending(pendingKey, false)
	if not ok then
		return false, "network_error"
	end
	if result == nil then
		return false, reason or "purchase_failed"
	end
	return true, nil
end

function ShopClient.openCrate(_cardId: string, crateId: string): (boolean, string?)
	local pendingKey = `Crate:{crateId}`
	if state.pending[pendingKey] then
		return false, "busy"
	end
	setPending(pendingKey, true)
	local ok, result, reason = pcall(Network.call, "OpenCrate", crateId)
	setPending(pendingKey, false)
	if not ok then
		return false, "network_error"
	end
	if result == nil then
		return false, reason or "purchase_failed"
	end
	acceptReveal(result)
	return true, nil
end

function ShopClient.promptProduct(_cardId: string, productId: number): (boolean, string?)
	local pendingKey = `ProductId:{productId}`
	if state.pending[pendingKey] then
		return false, "busy"
	end
	setPending(pendingKey, true)
	pendingProducts[productId] = pendingKey
	local ok = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, productId)
	if not ok then
		pendingProducts[productId] = nil
		setPending(pendingKey, false)
		return false, "marketplace_error"
	end
	return true, nil
end

function ShopClient.promptGamePass(_cardId: string, passId: number): (boolean, string?)
	local pendingKey = `GamePassId:{passId}`
	if state.pending[pendingKey] then
		return false, "busy"
	end
	setPending(pendingKey, true)
	pendingPasses[passId] = pendingKey
	local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, Players.LocalPlayer, passId)
	if not ok then
		pendingPasses[passId] = nil
		setPending(pendingKey, false)
		return false, "marketplace_error"
	end
	return true, nil
end

function ShopClient.clearReveal()
	if state.reveal ~= nil then
		update({ reveal = nil })
	end
end

function ShopClient.clearGrant()
	if state.grant ~= nil then
		update({ grant = nil })
	end
end

function ShopClient.snapshot(): Snapshot
	return state
end

function ShopClient.subscribe(callback: (Snapshot) -> ()): () -> ()
	table.insert(callbacks, callback)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

function ShopClient.stop()
	refreshGeneration += 1
	lifecycleGeneration += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(callbacks)
	table.clear(pendingProducts)
	table.clear(pendingPasses)
	table.clear(loadingPasses)
	table.clear(seenOpens)
	table.clear(seenGrants)
	started = false
	state = {
		status = "Idle",
		shopState = nil,
		metadata = {},
		ownedPasses = {},
		pending = {},
		reveal = nil,
		grant = nil,
	}
end

return ShopClient
