--!strict

-- Projects configured game passes and developer products into live-priced
-- storefront cards. Roblox prompts purchases; server services grant them.

local StoreOfferCardElement = require(script.Parent.Elements.StoreOfferCardElement)
local ButtonElement = require(script.Parent.Elements.ButtonElement)
local CratePresentation = require(script.Parent.CratePresentation)

type StartOptions = {
	marketplace: any?,
	player: Player?,
	menuManager: any?,
	cardElement: any?,
	buttonElement: any?,
	gamePasses: any?,
	products: any?,
	crates: any?,
	cosmetics: any?,
	storeCatalog: any?,
	paidRandomPolicy: any?,
	offersHolder: ScrollingFrame?,
	offerTitle: TextLabel?,
	cashActionMount: Frame?,
	crateHolder: ScrollingFrame?,
	shelfTitle: TextLabel?,
	runAsync: ((callback: () -> ()) -> ())?,
}

local StoreOffersController = {}

local started = false
local activeMarketplace: any = nil
local activePlayer: Player? = nil
local activeMenuManager: any = nil
local activeCardElement: any = StoreOfferCardElement
local activeButtonElement: any = ButtonElement
local activePaidRandomPolicy: any = nil
local activeCrates: any = nil
local activeCosmetics: any = nil
local activeRunAsync: (callback: () -> ()) -> () = function(callback)
	task.spawn(callback)
end
local offersHolder: ScrollingFrame? = nil
local offerTitle: TextLabel? = nil
local cashActionMount: Frame? = nil
local crateHolder: ScrollingFrame? = nil
local shelfTitle: TextLabel? = nil
local offers: { any } = {}
local offerByKey: { [string]: any } = {}
local states: { [string]: any } = {}
local busy: { [string]: boolean } = {}
local handles: { any } = {}
local cashHandle: any = nil
local connections: { any } = {}
local menuDisconnect: (() -> ())? = nil
local policyDisconnect: (() -> ())? = nil
local viewOpen = false
local paidRandomAllowed: boolean? = nil

local function replicatedStorage(): ReplicatedStorage
	return game:GetService("ReplicatedStorage")
end

local function resolveCatalogDependencies(): (any, any, any)
	local replicated = replicatedStorage()
	local config = replicated:WaitForChild("Config")
	local economy = replicated:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy")
	return require(config:WaitForChild("GamePasses")),
		require(config:WaitForChild("Products")),
		require(economy:WaitForChild("StoreCatalog"))
end

local function resolveMenuManager(): any
	return require(script.Parent.MenuManager)
end

local function resolveView(): (ScrollingFrame, TextLabel, Frame, ScrollingFrame, TextLabel)
	local players = game:GetService("Players")
	local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
	local view = playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("Shop")
	assert(view:IsA("CanvasGroup"), "[StoreOffersController] Views.Shop must be a CanvasGroup")
	local offersInstance = view:WaitForChild("OffersHolder")
	local titleInstance = view:WaitForChild("OfferTitle")
	local cashMountInstance = view:WaitForChild("CashActionMount")
	local crateInstance = view:WaitForChild("Holder")
	local shelfTitleInstance = view:WaitForChild("ShelfTitle")
	assert(
		offersInstance:IsA("ScrollingFrame"),
		"[StoreOffersController] Views.Shop.OffersHolder must be a ScrollingFrame"
	)
	assert(titleInstance:IsA("TextLabel"), "[StoreOffersController] Views.Shop.OfferTitle must be a TextLabel")
	assert(cashMountInstance:IsA("Frame"), "[StoreOffersController] Views.Shop.CashActionMount must be a Frame")
	assert(crateInstance:IsA("ScrollingFrame"), "[StoreOffersController] Views.Shop.Holder must be a ScrollingFrame")
	assert(shelfTitleInstance:IsA("TextLabel"), "[StoreOffersController] Views.Shop.ShelfTitle must be a TextLabel")
	return offersInstance, titleInstance, cashMountInstance, crateInstance, shelfTitleInstance
end

local function offerKey(offer: any): string
	return `{offer.kind}:{offer.key}`
end

local function styleFor(offer: any): string
	return if offer.kind == "GamePass" then "GamePass" else offer.definition.Type
end

local function badgeFor(offer: any): string
	if offer.kind == "GamePass" then
		return "PERMANENT PASS"
	elseif offer.definition.Type == "Cash" then
		return "CASH TOP-UP"
	elseif offer.definition.Type == "Crate" then
		return "ROBUX CRATE"
	end
	return "DEV PRODUCT"
end

local function detailsFor(offer: any): string
	if offer.kind == "Product" and offer.definition.Type == "Cash" then
		return `+{offer.definition.CashAmount} CASH  •  {offer.description}`
	elseif offer.kind == "Product" and offer.definition.Type == "Crate" then
		local crate = activeCrates and activeCrates[offer.definition.CrateId]
		if crate and activeCosmetics then
			return CratePresentation.forCrate(crate, activeCosmetics).odds
		end
	end
	return offer.description
end

local function imageFor(info: any): string
	local imageId = info and info.IconImageAssetId
	if type(imageId) ~= "number" or imageId <= 0 then
		return ""
	end
	return `rbxthumb://type=Asset&id={imageId}&w=420&h=420`
end

local function destroyCards()
	for _, handle in handles do
		handle:destroy()
	end
	table.clear(handles)
	if cashHandle then
		cashHandle:destroy()
		cashHandle = nil
	end
end

local function applyRegions(hasOffers: boolean)
	if offersHolder then
		offersHolder.Visible = hasOffers
	end
	if offerTitle then
		offerTitle.Visible = hasOffers
	end
	if crateHolder then
		crateHolder.Size = if hasOffers then UDim2.fromScale(0.5, 0.14) else UDim2.fromScale(0.82, 0.14)
	end
	if shelfTitle then
		shelfTitle.Size = if hasOffers then UDim2.fromScale(0.46, 0.05) else UDim2.fromScale(0.8, 0.05)
	end
end

local function stateData(offer: any, order: number): any
	local key = offerKey(offer)
	local state = states[key]
	local actionText = "LOADING..."
	local enabled = false
	local paidRandomOffer = offer.kind == "Product"
		and (offer.definition.Type == "Cash" or offer.definition.Type == "Crate")
	if paidRandomOffer and paidRandomAllowed ~= true then
		actionText = if paidRandomAllowed == nil then "CHECKING..." else "REGION LOCKED"
	elseif state and state.error then
		actionText = "UNAVAILABLE"
	elseif state and state.loaded then
		if state.owned then
			actionText = "OWNED"
		elseif not state.forSale then
			actionText = "OFF SALE"
		elseif busy[key] then
			actionText = "WAITING..."
		else
			actionText = `R$ {state.price}`
			enabled = true
		end
	end
	return {
		id = key,
		title = if state and state.title then state.title else offer.displayName,
		details = detailsFor(offer),
		badge = badgeFor(offer),
		image = if state and state.image then state.image else "",
		style = styleFor(offer),
		actionText = actionText,
		actionEnabled = enabled,
		layoutOrder = order,
	}
end

local render: () -> ()
local purchase: (string) -> ()

local function firstCashOffer(): any?
	for _, offer in offers do
		if offer.kind == "Product" and offer.definition.Type == "Cash" then
			return offer
		end
	end
	return nil
end

local function hasPaidRandomOffers(): boolean
	for _, offer in offers do
		if offer.kind == "Product" and (offer.definition.Type == "Cash" or offer.definition.Type == "Crate") then
			return true
		end
	end
	return false
end

local function cardWidthScale(): number
	local absoluteSize = if offersHolder then (offersHolder :: any).AbsoluteSize else nil
	if absoluteSize == nil or absoluteSize.Y <= 0 or absoluteSize.X <= 0 then
		return 0.62
	end
	return math.clamp((absoluteSize.Y * 0.92 * 2.05) / absoluteSize.X, 0.56, 0.94)
end

render = function()
	destroyCards()
	local hasOffers = #offers > 0
	applyRegions(hasOffers)
	if cashActionMount then
		cashActionMount.Visible = false
	end
	if not hasOffers or not viewOpen or offersHolder == nil then
		return
	end

	for order, offer in offers do
		local handle = activeCardElement.mount(offersHolder, {
			data = stateData(offer, order),
			activated = purchase,
		})
		if handle.instance then
			handle.instance.Size = UDim2.fromScale(cardWidthScale(), 0.92)
		end
		table.insert(handles, handle)
	end

	local cashOffer = firstCashOffer()
	if cashOffer and cashActionMount then
		local key = offerKey(cashOffer)
		local state = states[key]
		local enabled = paidRandomAllowed == true and state and state.loaded and state.forSale and not busy[key]
		cashActionMount.Visible = true
		cashHandle = activeButtonElement.mount(cashActionMount, {
			text = if enabled then "GET CASH" else "CASH",
			name = "GetCash",
			activated = function()
				purchase(key)
			end,
		})
		if cashHandle.instance then
			cashHandle.instance.AnchorPoint = Vector2.new(0.5, 0.5)
			cashHandle.instance.Position = UDim2.fromScale(0.5, 0.5)
			cashHandle.instance.Size = UDim2.fromScale(1, 1)
		end
		cashHandle:setEnabled(enabled == true)
	end
end

local function findByPlatformId(kind: string, platformId: number): string?
	for _, offer in offers do
		if offer.kind == kind and offer.id == platformId then
			return offerKey(offer)
		end
	end
	return nil
end

local function loadOffer(offer: any)
	local key = offerKey(offer)
	local infoType = if offer.kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
	local ok, info = pcall(function()
		return activeMarketplace:GetProductInfoAsync(offer.id, infoType)
	end)
	if not ok or type(info) ~= "table" then
		states[key] = { error = true }
		render()
		return
	end

	local owned = false
	if offer.kind == "GamePass" then
		local ownershipOk, ownership = pcall(function()
			return activeMarketplace:UserOwnsGamePassAsync((activePlayer :: Player).UserId, offer.id)
		end)
		if not ownershipOk then
			states[key] = { error = true }
			render()
			return
		end
		owned = ownership == true
	end

	local price = info.PriceInRobux
	states[key] = {
		loaded = true,
		owned = owned,
		forSale = type(price) == "number" and price >= 0 and info.IsForSale ~= false,
		price = if type(price) == "number" then price else 0,
		title = if type(info.Name) == "string" and info.Name ~= "" then info.Name else offer.displayName,
		image = imageFor(info),
	}
	render()
end

purchase = function(key: string)
	local offer = offerByKey[key]
	local state = states[key]
	local paidRandomOffer = offer
		and offer.kind == "Product"
		and (offer.definition.Type == "Cash" or offer.definition.Type == "Crate")
	if
		offer == nil
		or state == nil
		or not state.loaded
		or not state.forSale
		or state.owned
		or busy[key]
		or (paidRandomOffer and paidRandomAllowed ~= true)
	then
		return
	end
	busy[key] = true
	render()
	activeRunAsync(function()
		local ok = pcall(function()
			if offer.kind == "GamePass" then
				activeMarketplace:PromptGamePassPurchase(activePlayer, offer.id)
			else
				activeMarketplace:PromptProductPurchase(activePlayer, offer.id)
			end
		end)
		if not ok then
			busy[key] = nil
			render()
		end
	end)
end

local function connectMarketplaceSignals()
	table.insert(
		connections,
		activeMarketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if player ~= activePlayer then
				return
			end
			local key = findByPlatformId("GamePass", passId)
			if key == nil then
				return
			end
			busy[key] = nil
			if purchased then
				local state = states[key]
				if state then
					state.owned = true
				end
				render()
			else
				render()
			end
		end)
	)
	table.insert(
		connections,
		activeMarketplace.PromptProductPurchaseFinished:Connect(function(userId, productId, _purchased)
			if activePlayer == nil or userId ~= activePlayer.UserId then
				return
			end
			local key = findByPlatformId("Product", productId)
			if key then
				busy[key] = nil
				render()
			end
		end)
	)
end

function StoreOffersController.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	local defaultPasses, defaultProducts, defaultCatalog = resolveCatalogDependencies()
	local gamePasses = if options and options.gamePasses then options.gamePasses else defaultPasses
	local products = if options and options.products then options.products else defaultProducts
	activeCrates = if options and options.crates
		then options.crates
		else require(replicatedStorage():WaitForChild("Config"):WaitForChild("Crates"))
	activeCosmetics = if options and options.cosmetics
		then options.cosmetics
		else require(replicatedStorage():WaitForChild("Config"):WaitForChild("Cosmetics"))
	local storeCatalog = if options and options.storeCatalog then options.storeCatalog else defaultCatalog
	activeMenuManager = if options and options.menuManager then options.menuManager else resolveMenuManager()
	activeCardElement = if options and options.cardElement then options.cardElement else StoreOfferCardElement
	activeButtonElement = if options and options.buttonElement then options.buttonElement else ButtonElement
	activeRunAsync = if options and options.runAsync
		then options.runAsync
		else function(callback)
			task.spawn(callback)
		end
	offers = storeCatalog.build(gamePasses.Catalog, products.Catalog)
	for _, offer in offers do
		offerByKey[offerKey(offer)] = offer
	end

	if
		options
		and options.offersHolder
		and options.offerTitle
		and options.cashActionMount
		and options.crateHolder
		and options.shelfTitle
	then
		offersHolder = options.offersHolder
		offerTitle = options.offerTitle
		cashActionMount = options.cashActionMount
		crateHolder = options.crateHolder
		shelfTitle = options.shelfTitle
	else
		offersHolder, offerTitle, cashActionMount, crateHolder, shelfTitle = resolveView()
	end

	viewOpen = activeMenuManager.isOpen("Shop")
	if hasPaidRandomOffers() then
		activePaidRandomPolicy = if options and options.paidRandomPolicy
			then options.paidRandomPolicy
			else require(script.Parent.PaidRandomPolicyStore)
		activePaidRandomPolicy.start()
		paidRandomAllowed = activePaidRandomPolicy.snapshot()
		policyDisconnect = activePaidRandomPolicy.onChanged(function(allowed)
			paidRandomAllowed = allowed
			render()
		end)
	else
		paidRandomAllowed = true
	end
	menuDisconnect = activeMenuManager.onChanged(function(newMenu: string?)
		viewOpen = newMenu == "Shop"
		render()
	end)
	render()
	if #offers == 0 then
		return
	end

	activeMarketplace = if options and options.marketplace
		then options.marketplace
		else game:GetService("MarketplaceService")
	activePlayer = if options and options.player then options.player else game:GetService("Players").LocalPlayer
	connectMarketplaceSignals()
	if offersHolder and type((offersHolder :: any).GetPropertyChangedSignal) == "function" then
		table.insert(connections, offersHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))
	end
	for _, offer in offers do
		activeRunAsync(function()
			loadOffer(offer)
		end)
	end
end

function StoreOffersController._resetForTest()
	if menuDisconnect then
		menuDisconnect()
	end
	if policyDisconnect then
		policyDisconnect()
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	destroyCards()
	started = false
	activeMarketplace = nil
	activePlayer = nil
	activeMenuManager = nil
	activeCardElement = StoreOfferCardElement
	activeButtonElement = ButtonElement
	activePaidRandomPolicy = nil
	activeCrates = nil
	activeCosmetics = nil
	activeRunAsync = function(callback)
		task.spawn(callback)
	end
	offersHolder = nil
	offerTitle = nil
	cashActionMount = nil
	crateHolder = nil
	shelfTitle = nil
	table.clear(offers)
	table.clear(offerByKey)
	table.clear(states)
	table.clear(busy)
	table.clear(connections)
	menuDisconnect = nil
	policyDisconnect = nil
	viewOpen = false
	paidRandomAllowed = nil
end

return StoreOffersController
