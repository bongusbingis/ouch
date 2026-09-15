-- Description: Client adapter for the storefront: fetches offers, requests marketplace metadata, sends purchase and crate-open requests, and publishes the reveal and grant results for the UI.

--!strict

local Listeners = require(script.Parent.Parent.Util.Listeners)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("GamePasses"))
local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Products"))
local Seasons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Seasons"))
local BattlePassLogic = require(script.Parent.Parent.Progression.BattlePassLogic)
local DefaultNetwork = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Network = DefaultNetwork
local Marketplace = MarketplaceService
local localPlayer = Players.LocalPlayer
local ClientRequest = require(script.Parent.Parent.Data.ClientRequest)
local ShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))

export type Snapshot = {
	status: string,
	shopState: any?,
	metadata: { [string]: any },
	ownedPasses: { [string]: boolean },
	pending: { [string]: boolean },
	reveal: any?,
	grant: any?,
	purchaseNotice: boolean?,
	bonksRecovery: any?,
}

local ShopClient = {}

export type StartOptions = {
	DeferMarketplaceData: boolean?,
	Network: any?,
	Marketplace: any?,
	Player: any?,
}

local started = false
local refreshGeneration = 0
local lifecycleGeneration = 0
local callbacks: Listeners.Collection<Snapshot> = Listeners.new("ShopClient", false, "subscriber failed")
local connections: { RBXScriptConnection } = {}
local pendingProducts: { [number]: string } = {}
local pendingPasses: { [number]: string } = {}
local loadingPasses: { [string]: boolean } = {}
local seenOpens: { [string]: boolean } = {}
local seenGrants: { [string]: boolean } = {}
local purchaseBaselines: { [number]: { [string]: boolean } } = {}
local purchaseFinishedAt: { [string]: number } = {}
local purchaseNoticeShown: { [string]: boolean } = {}
local bonksIntent: any = nil
local nextBonksSequence: number? = nil
local latestBonksReveal = 0

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
	callbacks.emitWith(function(callback)
		callback(state)
	end)
end

-- Clearing a field has to go through this sentinel: `{ reveal = nil }` is an
-- empty table in Luau, so passing nil directly would silently clear nothing.
local CLEAR = table.freeze({})

local function update(changes: { [string]: any })
	local nextState = table.clone(state)
	for key, value in changes do
		nextState[key] = if value == CLEAR then nil else value
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
		purchaseFinishedAt[key] = nil
		purchaseNoticeShown[key] = nil
	end
	update({ pending = pending })
end

local function acceptReveal(payload: any)
	local openId = tostring(payload.openId or "")
	if openId == "" or seenOpens[openId] then
		return
	end
	if payload.source == "Bonks" and type(payload.sequence) == "number" then
		if payload.sequence < latestBonksReveal then
			return
		end
		latestBonksReveal = payload.sequence
		nextBonksSequence = math.max(nextBonksSequence or 1, payload.sequence + 1)
		if
			bonksIntent
			and payload.sequence == bonksIntent.sequence
			and payload.crateId == bonksIntent.crateId
			and payload.count == bonksIntent.count
		then
			bonksIntent.completed = true
			local key = `Crate:{bonksIntent.crateId}`
			bonksIntent = nil
			setPending(key, false)
			update({ bonksRecovery = CLEAR })
		end
	end
	seenOpens[openId] = true
	local completedProductId = nil
	local completedKey = nil
	for productId, key in pendingProducts do
		local definition = Products.ById[productId]
		if
			payload.source == "Robux"
			and definition ~= nil
			and definition.Type == "Crate"
			and definition.CrateId == payload.crateId
		then
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

local function acceptShopState(shopState: any)
	local recovery = shopState.bonksOpen
	if recovery and recovery.version == 1 and type(recovery.nextSequence) == "number" then
		nextBonksSequence = math.max(nextBonksSequence or 1, recovery.nextSequence)
	end
	update({ status = "Ready", shopState = shopState })
	if recovery and recovery.version == 1 and recovery.unrevealed then
		acceptReveal(recovery.unrevealed)
	end
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

local function recoverPurchases()
	local generation = lifecycleGeneration
	local ok, result = ClientRequest(Network.call, "GetPurchaseState")
	if not ok or type(result) ~= "table" or not started or generation ~= lifecycleGeneration then
		return
	end
	for _, receipt in result.receipts or {} do
		local baseline = purchaseBaselines[receipt.productId]
		if pendingProducts[receipt.productId] and baseline and not baseline[receipt.id] and receipt.payload then
			local payload = table.clone(receipt.payload)
			payload.productId = receipt.productId
			payload.grantId = receipt.id
			if payload.kind == "Crate" then
				acceptReveal(payload.reveal)
			else
				acceptGrant(payload)
			end
		end
	end
	for key, owned in result.ownedPasses or {} do
		local definition = GamePasses.Catalog[key]
		if owned and definition and definition.Id then
			local ownedPasses = table.clone(state.ownedPasses)
			ownedPasses[key] = true
			update({ ownedPasses = ownedPasses })
			if pendingPasses[definition.Id] then
				acceptGrant({ kind = "GamePass", passId = definition.Id, grantId = `pass:{definition.Id}` })
			end
		end
	end
end

local function metadataKey(kind: string, id: number): string
	return `{kind}:{id}`
end

local function requestMetadata(kind: string, id: number, infoType: Enum.InfoType)
	local key = metadataKey(kind, id)
	local existing = state.metadata[key]
	if
		existing ~= nil
		and (
			existing.loading == true
			or (existing.failed ~= true and os.clock() - (existing.fetchedAt or 0) < ShopConfig.MetadataRefreshSeconds)
		)
	then
		return
	end
	local metadata = table.clone(state.metadata)
	metadata[key] = { loading = true }
	update({ metadata = metadata })
	local generation = lifecycleGeneration
	task.spawn(function()
		local ok, info = ClientRequest(Marketplace.GetProductInfoAsync, Marketplace, id, infoType)
		if not started or generation ~= lifecycleGeneration then
			return
		end
		local nextMetadata = table.clone(state.metadata)
		if ok and type(info) == "table" then
			nextMetadata[key] = {
				name = info.Name,
				priceInRobux = info.PriceInRobux,
				isForSale = info.IsForSale ~= false,
				fetchedAt = os.clock(),
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
				local ok, owned =
					ClientRequest(Marketplace.UserOwnsGamePassAsync, Marketplace, localPlayer.UserId, passId)
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

function ShopClient.start(options: StartOptions?)
	if started then
		return
	end
	Network = if options and options.Network then options.Network else DefaultNetwork
	Marketplace = if options and options.Marketplace then options.Marketplace else MarketplaceService
	localPlayer = if options and options.Player then options.Player else Players.LocalPlayer
	started = true
	lifecycleGeneration += 1
	table.insert(
		connections,
		Network.on("ShopStateChanged", function(shopState)
			refreshGeneration += 1
			acceptShopState(shopState)
		end)
	)
	table.insert(connections, Network.on("CrateOpened", acceptReveal))
	table.insert(connections, Network.on("StorePurchaseGranted", acceptGrant))
	table.insert(
		connections,
		Marketplace.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
			if userId ~= localPlayer.UserId then
				return
			end
			local key = pendingProducts[productId]
			if key and not purchased then
				pendingProducts[productId] = nil
				setPending(key, false)
			elseif key then
				purchaseFinishedAt[key] = os.clock()
			end
		end)
	)
	table.insert(
		connections,
		Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if player ~= localPlayer then
				return
			end
			local key = pendingPasses[passId]
			if key and not purchased then
				pendingPasses[passId] = nil
				setPending(key, false)
			elseif key then
				purchaseFinishedAt[key] = os.clock()
			end
		end)
	)
	if not (options and options.DeferMarketplaceData) then
		loadMarketplaceData()
	end
	local generation = lifecycleGeneration
	task.spawn(function()
		while started and generation == lifecycleGeneration do
			task.wait(ShopConfig.PurchasePollSeconds)
			if not started or generation ~= lifecycleGeneration then
				return
			end
			if next(pendingProducts) or next(pendingPasses) then
				recoverPurchases()
			end
			if not started or generation ~= lifecycleGeneration then
				return
			end
			if state.status == "Error" then
				ShopClient.refresh()
				if not started or generation ~= lifecycleGeneration then
					return
				end
			end
			for key, finishedAt in purchaseFinishedAt do
				if
					state.pending[key]
					and not purchaseNoticeShown[key]
					and os.clock() - finishedAt >= ShopConfig.PurchaseNoticeSeconds
				then
					purchaseNoticeShown[key] = true
					update({ purchaseNotice = true })
				end
			end
		end
	end)
end

function ShopClient.ensureMarketplaceData()
	if started then
		loadMarketplaceData()
	end
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
	local ok, result = ClientRequest(Network.call, "GetShopState")
	if generation ~= refreshGeneration then
		return false, "stale"
	end
	if not ok or type(result) ~= "table" then
		update({ status = "Error" })
		return false, "network_error"
	end
	acceptShopState(result)
	return true, nil
end

function ShopClient.purchaseCosmetic(_cardId: string, itemId: string): (boolean, string?)
	local pendingKey = `Cosmetic:{itemId}`
	if state.pending[pendingKey] then
		return false, "busy"
	end
	setPending(pendingKey, true)
	local generation = lifecycleGeneration
	local ok, result, reason = ClientRequest(Network.call, "PurchaseCosmetic", itemId)
	if generation ~= lifecycleGeneration then
		return false, "stale"
	end
	setPending(pendingKey, false)
	if not ok then
		return false, if result == "request_timed_out" then "request_timed_out" else "network_error"
	end
	if result == nil then
		return false, reason or "purchase_failed"
	end
	return true, nil
end

local function randomPurchaseAllowed(): (boolean, string?)
	local snapshot = state.shopState
	if snapshot == nil or snapshot.paidRandomAllowed ~= true then
		return false, if snapshot then snapshot.paidRandomReason or "policy_unavailable" else "policy_unavailable"
	end
	return true, nil
end

local function recoverySupported(): boolean
	local recovery = state.shopState and state.shopState.bonksOpen
	return recovery ~= nil and recovery.version == 1 and nextBonksSequence ~= nil
end

local function attemptBonksOpen(intent: any): (boolean, string?)
	if not recoverySupported() then
		return false, "crate_recovery_unavailable"
	end
	if intent.active then
		return false, "busy"
	end
	intent.active = true
	local pendingKey = `Crate:{intent.crateId}`
	setPending(pendingKey, true)
	local generation = lifecycleGeneration
	local ok, result, reason =
		ClientRequest(Network.call, "OpenCrate", intent.crateId, intent.count, intent.sequence, intent.unitPrice)
	intent.active = false
	if generation ~= lifecycleGeneration then
		return false, "stale"
	end
	-- An event may finish this intent while its response is lost or still waiting.
	if intent.completed then
		return true, nil
	end
	if
		type(result) == "table"
		and result.source == "Bonks"
		and result.sequence == intent.sequence
		and result.crateId == intent.crateId
		and result.count == intent.count
	then
		acceptReveal(result)
		return true, nil
	end
	if bonksIntent == intent then
		setPending(pendingKey, false)
	end
	if
		not ok
		or (result ~= nil)
		or reason == "crate_processing"
		or reason == "crate_recovery_required"
		or reason == "no_profile"
		or reason == "rate_limited"
		or reason == "invalid_args"
		or reason == nil
	then
		update({ bonksRecovery = { sequence = intent.sequence, crateId = intent.crateId } })
		return false, "crate_recovery_required"
	end
	-- An authoritative rejection proves this request did not create a new open.
	if bonksIntent == intent then
		bonksIntent = nil
		update({ bonksRecovery = CLEAR })
	end
	if reason == "crate_price_changed" or reason == "crate_request_stale" or reason == "crate_request_gap" then
		task.spawn(ShopClient.refresh)
	end
	return false, reason or "purchase_failed"
end

function ShopClient.retryCrateOpen(): (boolean, string?)
	if bonksIntent == nil then
		return true, nil
	end
	return attemptBonksOpen(bonksIntent)
end

function ShopClient.openCrate(_cardId: string, crateId: string, count: number?, unitPrice: number?): (boolean, string?)
	if bonksIntent then
		return false, if bonksIntent.active then "busy" else "crate_recovery_required"
	end
	if not recoverySupported() then
		return false, "crate_recovery_unavailable"
	end
	local allowed, policyReason = randomPurchaseAllowed()
	if not allowed then
		return false, policyReason
	end
	if type(unitPrice) ~= "number" or unitPrice ~= unitPrice or unitPrice <= 0 or unitPrice == math.huge then
		return false, "crate_price_changed"
	end
	local intent = { sequence = nextBonksSequence, crateId = crateId, count = count or 1, unitPrice = unitPrice }
	bonksIntent = intent
	local generation = lifecycleGeneration
	local ok, reason = attemptBonksOpen(intent)
	if not ok and reason == "crate_recovery_required" then
		-- One automatic recovery only, with the same identity and quote. Legacy
		-- servers never enter this path because they advertise no capability.
		intent.active = true
		setPending(`Crate:{intent.crateId}`, true)
		task.wait(1)
		if generation ~= lifecycleGeneration then
			return false, "stale"
		end
		intent.active = false
		if intent.completed then
			return true, nil
		end
		return attemptBonksOpen(intent)
	end
	return ok, reason
end

function ShopClient.promptProduct(_cardId: string, productId: number): (boolean, string?)
	local definition = Products.ById[productId]
	if definition == nil or definition.CatalogStatus ~= "Active" then
		return false, "unavailable"
	end
	if definition.Type == "Crate" then
		local allowed, policyReason = randomPurchaseAllowed()
		if not allowed then
			return false, policyReason
		end
	end
	if definition.Type == "SeasonPass" then
		local season = BattlePassLogic.activeSeason(Seasons.Definitions, os.time())
		if season == nil or season.Id ~= definition.SeasonId then
			return false, "season_ended"
		end
	end
	local pendingKey = `ProductId:{productId}`
	if state.pending[pendingKey] then
		return false, "busy"
	end
	setPending(pendingKey, true)
	local generation = lifecycleGeneration
	local fetched, status = ClientRequest(Network.call, "GetPurchaseState")
	if not started or generation ~= lifecycleGeneration then
		return false, "stale"
	end
	if not fetched or type(status) ~= "table" then
		setPending(pendingKey, false)
		return false, "marketplace_error"
	end
	local baseline = {}
	for _, receipt in status.receipts or {} do
		baseline[receipt.id] = true
	end
	purchaseBaselines[productId] = baseline
	pendingProducts[productId] = pendingKey
	local ok = pcall(Marketplace.PromptProductPurchase, Marketplace, localPlayer, productId)
	if not ok then
		pendingProducts[productId] = nil
		setPending(pendingKey, false)
		return false, "marketplace_error"
	end
	return true, nil
end

function ShopClient.promptGamePass(_cardId: string, passId: number): (boolean, string?)
	local definition = GamePasses.ById[passId]
	if definition == nil or definition.CatalogStatus ~= "Active" then
		return false, "unavailable"
	end
	local pendingKey = `GamePassId:{passId}`
	if state.pending[pendingKey] then
		return false, "busy"
	end
	setPending(pendingKey, true)
	pendingPasses[passId] = pendingKey
	local ok = pcall(Marketplace.PromptGamePassPurchase, Marketplace, localPlayer, passId)
	if not ok then
		pendingPasses[passId] = nil
		setPending(pendingKey, false)
		return false, "marketplace_error"
	end
	return true, nil
end

function ShopClient.clearReveal()
	if state.reveal ~= nil then
		local reveal = state.reveal
		if reveal.source == "Bonks" and type(reveal.sequence) == "number" then
			pcall(Network.fireServer, "AcknowledgeBonksCrate", reveal.sequence)
		end
		update({ reveal = CLEAR })
	end
end

function ShopClient.clearGrant()
	if state.grant ~= nil then
		update({ grant = CLEAR })
	end
end

function ShopClient.clearPurchaseNotice()
	update({ purchaseNotice = CLEAR })
end

function ShopClient.snapshot(): Snapshot
	return state
end

function ShopClient.subscribe(callback: (Snapshot) -> ()): () -> ()
	local unsubscribe = callbacks.add(callback)
	return unsubscribe
end

function ShopClient.stop()
	refreshGeneration += 1
	lifecycleGeneration += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	callbacks.clear()
	table.clear(pendingProducts)
	table.clear(pendingPasses)
	table.clear(loadingPasses)
	table.clear(seenOpens)
	table.clear(seenGrants)
	table.clear(purchaseBaselines)
	table.clear(purchaseFinishedAt)
	table.clear(purchaseNoticeShown)
	bonksIntent = nil
	nextBonksSequence = nil
	latestBonksReveal = 0
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
