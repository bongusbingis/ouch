--!strict

-- Owns the complete storefront projection, marketplace prompts, crate
-- disclosure, and purchase-result presentation. Server services remain the
-- only grant authority.

local ButtonElement = require(script.Parent.Elements.ButtonElement)
local CrateCardElement = require(script.Parent.Elements.CrateCardElement)
local StoreOfferCardElement = require(script.Parent.Elements.StoreOfferCardElement)
local EconomyItemElement = require(script.Parent.Elements.EconomyItemElement)
local CratePresentation = require(script.Parent.CratePresentation)
local EconomyStore = require(script.Parent.EconomyStore)

type StartOptions = {
	store: any?,
	network: any?,
	menuManager: any?,
	crateElement: any?,
	itemElement: any?,
	offerElement: any?,
	directElement: any?,
	buttonElement: any?,
	crates: any?,
	cosmetics: any?,
	products: any?,
	gamePasses: any?,
	shop: any?,
	storeCatalog: any?,
	paidRandomPolicy: any?,
	marketplace: any?,
	player: Player?,
	holder: Frame?,
	cratesHolder: Frame?,
	featuredMount: Frame?,
	cashOffersHolder: Frame?,
	passesHolder: Frame?,
	directHolder: Frame?,
	cashLabel: TextLabel?,
	statusLabel: TextLabel?,
	viewNodes: any?,
	runAsync: ((callback: () -> ()) -> ())?,
	wait: ((seconds: number) -> ())?,
	now: (() -> number)?,
}

local ShopController = {}

local started = false
local activeStore: any = EconomyStore
local activeNetwork: any = nil
local activeMenuManager: any = nil
local activeCrateElement: any = CrateCardElement
local activeOfferElement: any = StoreOfferCardElement
local activeDirectElement: any = EconomyItemElement
local activeDirectPurchase: any = nil
local activeStarterOffer: any = nil
local activeFeaturedRotation: any = nil
local activeShop: any = nil
local starterListeners: { (active: boolean) -> () } = {}
local starterActive = false
local activeButtonElement: any = ButtonElement
local activeCrates: any = nil
local activeCosmetics: any = nil
local activeProducts: any = nil
local activeGamePasses: any = nil
local activeStoreCatalog: any = nil
local activePaidRandomPolicy: any = nil
local activeMarketplace: any = nil
local activePlayer: Player? = nil

local function runAsyncDefault(callback: () -> ())
	if task then
		task.spawn(callback)
	else
		callback()
	end
end

local function waitDefault(seconds: number)
	if task then
		task.wait(seconds)
	end
end

local activeRunAsync: (callback: () -> ()) -> () = runAsyncDefault
local activeWait: (seconds: number) -> () = waitDefault
local activeNow: () -> number = function()
	return os.time()
end

-- Buttons are mounted into fixed Frames, so every one fills its mount. Guarded
-- because the headless test loader has no UDim2, matching EconomyPrototypeLayout.
local function fillMount(handle: any)
	if handle.instance == nil or UDim2 == nil then
		return
	end
	handle.instance.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.instance.Position = UDim2.fromScale(0.5, 0.5)
	handle.instance.Size = UDim2.fromScale(1, 1)
end

local nodes: any = nil
local currentData: any = nil
local offers: { any } = {}
local offersByKey: { [string]: any } = {}
local crateProducts: { [string]: any } = {}
local states: { [string]: any } = {}
local busy: { [string]: boolean } = {}
local cardHandles: { any } = {}
local modalHandles: { any } = {}
local connections: { any } = {}
local seenOpenIds: { [string]: boolean } = {}
local seenOpenOrder: { string } = {}
local seenGrantIds: { [string]: boolean } = {}
local viewOpen = false
local storeDisconnect: (() -> ())? = nil
local menuDisconnect: (() -> ())? = nil
local policyDisconnect: (() -> ())? = nil
local statusMessage = "Economy data is loading."
local paidRandomAllowed: boolean? = true
local detailSelection: { crateId: string, path: string }? = nil
local revealGeneration = 0
local activeRevealTween: any = nil

local function replicatedStorage(): any
	if game == nil then
		local root = script.Parent.Parent.Parent.Parent.Parent.Parent
		return root:WaitForChild("ReplicatedStorage")
	end
	return game:GetService("ReplicatedStorage")
end

local function resolveDependency(name: string): any
	return require(replicatedStorage():WaitForChild("Config"):WaitForChild(name))
end

local function resolveStoreCatalog(): any
	return require(
		replicatedStorage()
			:WaitForChild("Shared")
			:WaitForChild("Game")
			:WaitForChild("Economy")
			:WaitForChild("StoreCatalog")
	)
end

local function resolveView(): any
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local view = playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("Shop")
	assert(view:IsA("CanvasGroup"), "[ShopController] Views.Shop must be a CanvasGroup")
	local header = view:WaitForChild("ShopHeader")
	local storefront = view:WaitForChild("Storefront")
	local starterSection = storefront:WaitForChild("StarterSection")
	local featuredSection = storefront:WaitForChild("FeaturedSection")
	local cratesSection = storefront:WaitForChild("CratesSection")
	local directSection = storefront:WaitForChild("DirectSection")
	local cashSection = storefront:WaitForChild("CashSection")
	local passesSection = storefront:WaitForChild("PassesSection")
	local details = view:WaitForChild("DetailsOverlay")
	local reveal = view:WaitForChild("RevealOverlay")
	assert(header:IsA("Frame"), "[ShopController] ShopHeader must be a Frame")
	assert(storefront:IsA("ScrollingFrame"), "[ShopController] Storefront must be a ScrollingFrame")
	assert(starterSection:IsA("Frame"), "[ShopController] StarterSection must be a Frame")
	assert(featuredSection:IsA("Frame"), "[ShopController] FeaturedSection must be a Frame")
	assert(cratesSection:IsA("Frame"), "[ShopController] CratesSection must be a Frame")
	assert(directSection:IsA("Frame"), "[ShopController] DirectSection must be a Frame")
	assert(cashSection:IsA("Frame"), "[ShopController] CashSection must be a Frame")
	assert(passesSection:IsA("Frame"), "[ShopController] PassesSection must be a Frame")
	assert(details:IsA("CanvasGroup"), "[ShopController] DetailsOverlay must be a CanvasGroup")
	assert(reveal:IsA("CanvasGroup"), "[ShopController] RevealOverlay must be a CanvasGroup")

	local cashCard = header:WaitForChild("CashCard")
	local cash = cashCard:WaitForChild("Cash")
	local status = header:WaitForChild("Status")
	local jumpTabs = header:WaitForChild("JumpTabs")
	local detailsPanel = details:WaitForChild("Panel")
	local oddsList = detailsPanel:WaitForChild("OddsList")
	local revealPanel = reveal:WaitForChild("Panel")
	assert(cash:IsA("TextLabel"), "[ShopController] ShopHeader.CashCard.Cash must be a TextLabel")
	assert(status:IsA("TextLabel"), "[ShopController] ShopHeader.Status must be a TextLabel")
	assert(jumpTabs:IsA("Frame"), "[ShopController] ShopHeader.JumpTabs must be a Frame")
	assert(detailsPanel:IsA("Frame"), "[ShopController] DetailsOverlay.Panel must be a Frame")
	assert(oddsList:IsA("ScrollingFrame"), "[ShopController] DetailsOverlay.Panel.OddsList must be a ScrollingFrame")
	assert(revealPanel:IsA("Frame"), "[ShopController] RevealOverlay.Panel must be a Frame")

	return {
		view = view,
		header = header,
		storefront = storefront,
		starterSection = starterSection,
		starterHeadline = starterSection:WaitForChild("Headline"),
		starterDetail = starterSection:WaitForChild("Detail"),
		starterTimer = starterSection:WaitForChild("Timer"),
		starterActionMount = starterSection:WaitForChild("ActionMount"),
		featuredSection = featuredSection,
		featuredTitle = featuredSection:WaitForChild("SectionTitle"),
		cratesSection = cratesSection,
		directSection = directSection,
		cashSection = cashSection,
		passesSection = passesSection,
		featuredMount = featuredSection:WaitForChild("FeaturedMount"),
		cratesHolder = cratesSection:WaitForChild("CratesHolder"),
		directHolder = directSection:WaitForChild("DirectHolder"),
		cashOffersHolder = cashSection:WaitForChild("CashOffersHolder"),
		passesHolder = passesSection:WaitForChild("PassesHolder"),
		cashLabel = cash,
		statusLabel = status,
		closeButton = header:WaitForChild("Close"),
		jumpTabs = jumpTabs,
		detailsOverlay = details,
		detailsTitle = detailsPanel:WaitForChild("Title"),
		detailsSummary = detailsPanel:WaitForChild("Summary"),
		outcomeText = oddsList:WaitForChild("OutcomeText"),
		detailsConfirmMount = detailsPanel:WaitForChild("ConfirmMount"),
		detailsCancelMount = detailsPanel:WaitForChild("CancelMount"),
		revealOverlay = reveal,
		revealGlyph = revealPanel:WaitForChild("Glyph"),
		revealTitle = revealPanel:WaitForChild("Title"),
		revealDetails = revealPanel:WaitForChild("Details"),
		revealActionMount = revealPanel:WaitForChild("ActionMount"),
	}
end

local function offerKey(offer: any): string
	return `{offer.kind}:{offer.key}`
end

local function isActive(definition: any): boolean
	if definition.CatalogStatus ~= nil then
		return definition.CatalogStatus == "Active"
	end
	return definition.Enabled == true
end

local function destroyHandles(handles: { any })
	for _, handle in handles do
		handle:destroy()
	end
	table.clear(handles)
end

local function setStatus(message: string)
	statusMessage = message
	if nodes and nodes.statusLabel then
		nodes.statusLabel.Text = message
	end
end

local function report(kind: string, offer: any?)
	if activeNetwork == nil or type(activeNetwork.fireServer) ~= "function" then
		return
	end
	local payload = {
		kind = kind,
		offerKey = if offer then offer.key else nil,
		offerKind = if offer then offer.kind else nil,
	}
	pcall(activeNetwork.fireServer, "ReportAnalyticsEvent", payload)
end

local function presentationFor(crate: any): any
	if activeCosmetics == nil or activeCosmetics.Rarities == nil then
		return {
			highlight = `{#crate.ItemPool} COSMETICS INSIDE`,
			odds = "ODDS SHOWN BEFORE PURCHASE",
			rarityCount = 0,
			outcomes = {},
		}
	end
	return CratePresentation.forCrate(crate, activeCosmetics)
end

local function sortedCrateIds(): { string }
	local ids = {}
	for crateId in activeCrates do
		table.insert(ids, crateId)
	end
	table.sort(ids, function(left, right)
		local leftName = activeCrates[left].DisplayName or left
		local rightName = activeCrates[right].DisplayName or right
		if leftName == rightName then
			return left < right
		end
		return leftName < rightName
	end)
	return ids
end

-- The configured rotation decides the slot; the rarity fallback only covers a
-- rotation that names a crate this build no longer ships.
local function featuredCrateId(ids: { string }): string?
	if activeFeaturedRotation ~= nil and activeShop ~= nil then
		local entry = activeFeaturedRotation.select(activeShop.Featured, activeNow())
		if entry ~= nil and entry.kind == "Crate" and activeCrates[entry.id] ~= nil then
			return entry.id
		end
	end
	local selected: string? = nil
	local selectedRarityCount = -1
	for _, crateId in ids do
		local rarityCount = presentationFor(activeCrates[crateId]).rarityCount
		if rarityCount > selectedRarityCount then
			selected = crateId
			selectedRarityCount = rarityCount
		end
	end
	return selected
end

-- Mirrors CrateService.priceFor so the advertised price is the charged price.
local function cashPriceFor(crateId: string): number?
	local crate = activeCrates[crateId]
	if crate == nil or crate.CashPrice == nil then
		return nil
	end
	if activeFeaturedRotation == nil or activeShop == nil then
		return crate.CashPrice
	end
	return activeFeaturedRotation.priceFor(activeShop.Featured, crateId, crate.CashPrice, activeNow())
end

local function resultMessage(result: any): string
	local item = result and activeCosmetics.Items[result.itemId]
	local displayName = if item then item.DisplayName else (result and result.itemId) or "Unknown item"
	if result and result.isDupe then
		return `Duplicate {displayName}; refunded {result.cashRefund or 0} Cash.`
	end
	return `Unlocked {displayName}.`
end

local function errorMessage(reason: any): string
	if reason == "insufficient_cash" then
		return "Not enough Cash."
	elseif reason == "rate_limited" then
		return "Please wait before opening another crate."
	elseif reason == "no_profile" then
		return "Economy data is still loading."
	elseif reason == "invalid_crate" then
		return "This crate is unavailable."
	elseif reason == "paid_random_restricted" then
		return "Paid random items are unavailable in your region."
	elseif reason == "policy_unavailable" then
		return "Purchase eligibility could not be verified. Please try again."
	end
	return `Purchase failed: {tostring(reason or "unknown error")}`
end

local function imageFor(info: any): string
	local imageId = info and info.IconImageAssetId
	if type(imageId) ~= "number" or imageId <= 0 then
		return ""
	end
	return `rbxthumb://type=Asset&id={imageId}&w=420&h=420`
end

local function addSeenOpen(openId: string): boolean
	if seenOpenIds[openId] then
		return false
	end
	seenOpenIds[openId] = true
	table.insert(seenOpenOrder, openId)
	if #seenOpenOrder > 100 then
		seenOpenIds[table.remove(seenOpenOrder, 1)] = nil
	end
	return true
end

local function finishReveal(result: any)
	if activeRevealTween then
		activeRevealTween:Cancel()
		activeRevealTween = nil
	end
	revealGeneration += 1
	if nodes == nil or nodes.revealOverlay == nil then
		setStatus(resultMessage(result))
		return
	end
	destroyHandles(modalHandles)
	nodes.revealGlyph.Rotation = 0
	nodes.revealGlyph.Text = string.upper(result.rarity or "NEW")
	nodes.revealTitle.Text = resultMessage(result)
	nodes.revealDetails.Text = if result.isDupe
		then `DUPLICATE REFUND: {result.cashRefund or 0} CASH`
		else `{string.upper(result.rarity or "COSMETIC")} DROP`
	local handle = activeButtonElement.mount(nodes.revealActionMount, {
		text = "CLOSE",
		name = "CloseReveal",
		activated = function()
			nodes.revealOverlay.Visible = false
			destroyHandles(modalHandles)
		end,
	})
	fillMount(handle)
	table.insert(modalHandles, handle)
	setStatus(resultMessage(result))
end

local function showReveal(result: any)
	local openId = if result and type(result.openId) == "string"
		then result.openId
		else `legacy:{result and result.crateId}:{result and result.itemId}:{result and result.source}`
	if not addSeenOpen(openId) then
		return
	end
	if nodes == nil or nodes.revealOverlay == nil then
		setStatus(resultMessage(result))
		return
	end

	revealGeneration += 1
	local generation = revealGeneration
	destroyHandles(modalHandles)
	nodes.revealOverlay.Visible = true
	nodes.revealGlyph.Text = "?"
	nodes.revealGlyph.Rotation = 0
	activeRevealTween = game:GetService("TweenService"):Create(
		nodes.revealGlyph,
		TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Rotation = 360 }
	)
	activeRevealTween:Play()
	nodes.revealTitle.Text = "OPENING..."
	nodes.revealDetails.Text = "Tap skip to reveal instantly."
	local skip = activeButtonElement.mount(nodes.revealActionMount, {
		text = "SKIP",
		name = "SkipReveal",
		activated = function()
			if generation == revealGeneration then
				finishReveal(result)
			end
		end,
	})
	fillMount(skip)
	table.insert(modalHandles, skip)
	activeRunAsync(function()
		activeWait(0.7)
		if generation == revealGeneration and nodes.revealOverlay.Visible then
			finishReveal(result)
		end
	end)
end

local render: () -> ()

local function closeDetails()
	detailSelection = nil
	if nodes and nodes.detailsOverlay then
		nodes.detailsOverlay.Visible = false
	end
	destroyHandles(modalHandles)
end

local function openCashCrate(crateId: string)
	if busy[`Cash:{crateId}`] or paidRandomAllowed ~= true then
		setStatus("Paid random items are unavailable in your region.")
		return
	end
	busy[`Cash:{crateId}`] = true
	setStatus("Opening crate...")
	report("PromptOpened", { key = crateId, kind = "CashCrate" })
	render()
	activeRunAsync(function()
		local callOk, result, reason = pcall(activeNetwork.call, "OpenCrate", crateId)
		busy[`Cash:{crateId}`] = nil
		if not callOk then
			setStatus("Purchase failed: network error.")
			report("PurchaseFailed", { key = crateId, kind = "CashCrate" })
		elseif result == nil then
			setStatus(errorMessage(reason))
			report("PurchaseFailed", { key = crateId, kind = "CashCrate" })
		else
			showReveal(result)
		end
		render()
	end)
end

-- Direct buys are deterministic, so they deliberately skip the paid-random
-- policy gate and the reveal ritual: the player already knows what they get.
local function purchaseCosmetic(itemId: string)
	local key = `Direct:{itemId}`
	if busy[key] then
		return
	end
	busy[key] = true
	setStatus("Purchasing...")
	report("OfferSelected", { key = itemId, kind = "DirectBuy" })
	render()
	activeRunAsync(function()
		local callOk, result, reason = pcall(activeNetwork.call, "PurchaseCosmetic", itemId)
		busy[key] = nil
		if not callOk then
			setStatus("Purchase failed: network error.")
			report("PurchaseFailed", { key = itemId, kind = "DirectBuy" })
		elseif result == nil then
			setStatus(errorMessage(reason))
			report("PurchaseFailed", { key = itemId, kind = "DirectBuy" })
		else
			local item = activeCosmetics.Items[result.itemId]
			setStatus(`Unlocked {if item then item.DisplayName else result.itemId}.`)
		end
		render()
	end)
end

local function purchaseOffer(key: string)
	local offer = offersByKey[key]
	local state = states[key]
	local paidRandom = offer
		and offer.kind == "Product"
		and (offer.definition.Type == "Cash" or offer.definition.Type == "Crate")
	if
		offer == nil
		or state == nil
		or not state.loaded
		or not state.forSale
		or state.owned
		or busy[key]
		or offer.status ~= "Active"
		or (paidRandom and paidRandomAllowed ~= true)
	then
		return
	end

	busy[key] = true
	setStatus("Opening Roblox purchase prompt...")
	report("PromptOpened", offer)
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
			setStatus("The Roblox purchase prompt is unavailable.")
			report("PurchaseFailed", offer)
			render()
		end
	end)
end

local function oddsDisclosure(presentation: any): string
	local lines = {
		"Every possible result and its probability:",
		"",
	}
	for _, outcome in presentation.outcomes do
		table.insert(lines, `{outcome.displayName} - {string.upper(outcome.rarity)} - {outcome.percentText}%`)
	end
	if #presentation.outcomes == 0 then
		table.insert(lines, "Outcome probabilities are unavailable.")
	else
		table.insert(lines, "")
		table.insert(lines, "TOTAL - 100%")
	end
	if #presentation.pity > 0 then
		table.insert(lines, "")
		table.insert(lines, "Guaranteed drops:")
		for _, guarantee in presentation.pity do
			table.insert(
				lines,
				`{string.upper(guarantee.rarity)} at least once every {guarantee.threshold} opens of this crate`
			)
		end
	end
	return table.concat(lines, "\n")
end

local function showDetails(crateId: string, path: string)
	local crate = activeCrates[crateId]
	if crate == nil or nodes == nil or nodes.detailsOverlay == nil then
		return
	end
	detailSelection = { crateId = crateId, path = path }
	local presentation = presentationFor(crate)
	local oddsReady = #presentation.outcomes > 0
	nodes.detailsTitle.Text = crate.DisplayName or crateId
	nodes.detailsSummary.Text = `{presentation.highlight}  |  Cosmetics only; no gameplay advantage.`
	nodes.outcomeText.Text = oddsDisclosure(presentation)
	nodes.detailsOverlay.Visible = true
	destroyHandles(modalHandles)

	local cancel = activeButtonElement.mount(nodes.detailsCancelMount, {
		text = "BACK",
		name = "CancelDetails",
		activated = closeDetails,
	})
	fillMount(cancel)
	table.insert(modalHandles, cancel)

	local confirmText = "UNAVAILABLE"
	local confirmEnabled = false
	local confirm: () -> ()
	if path == "Robux" then
		local offer = crateProducts[crateId]
		local key = offer and offerKey(offer)
		local state = key and states[key]
		if state and state.loaded and state.forSale and paidRandomAllowed == true and oddsReady and not busy[key] then
			confirmText = `BUY - R$ {state.price}`
			confirmEnabled = true
		end
		confirm = function()
			if key then
				closeDetails()
				purchaseOffer(key)
			end
		end
	else
		local price = cashPriceFor(crateId)
		local cash = currentData and currentData.Cash or 0
		if price and cash >= price and paidRandomAllowed == true and oddsReady and not busy[`Cash:{crateId}`] then
			confirmText = `OPEN - {price} CASH`
			confirmEnabled = true
		elseif price and cash < price then
			confirmText = "NOT ENOUGH CASH"
		end
		confirm = function()
			closeDetails()
			openCashCrate(crateId)
		end
	end

	local confirmHandle = activeButtonElement.mount(nodes.detailsConfirmMount, {
		text = confirmText,
		name = "ConfirmDetails",
		activated = confirm,
	})
	fillMount(confirmHandle)
	confirmHandle:setEnabled(confirmEnabled)
	table.insert(modalHandles, confirmHandle)
	report("OfferSelected", { key = crateId, kind = `{path}Crate` })
end

local function actionForCrate(crateId: string, action: string)
	if nodes == nil or nodes.detailsOverlay == nil then
		if action == "Cash" then
			openCashCrate(crateId)
		end
		return
	end
	if action == "Details" then
		showDetails(crateId, "Cash")
	else
		showDetails(crateId, action)
	end
end

local function cashValueBadge(offer: any): string
	local state = states[offerKey(offer)]
	if state == nil or not state.loaded or state.price <= 0 then
		return "CASH TOP-UP"
	end
	local baseline: number? = nil
	for _, other in offers do
		if other.kind == "Product" and other.definition.Type == "Cash" then
			local otherState = states[offerKey(other)]
			if otherState and otherState.loaded and otherState.price > 0 then
				local rate = other.definition.CashAmount / otherState.price
				if baseline == nil or rate < baseline then
					baseline = rate
				end
			end
		end
	end
	if baseline == nil then
		return "CASH TOP-UP"
	end
	local value = offer.definition.CashAmount / state.price
	local increase = math.floor((value / baseline - 1) * 100 + 0.5)
	return if increase >= 2 then `+{increase}% VALUE` else "CASH TOP-UP"
end

local function offerData(offer: any, order: number): any
	local key = offerKey(offer)
	local state = states[key]
	local paidRandom = offer.kind == "Product" and (offer.definition.Type == "Cash" or offer.definition.Type == "Crate")
	local actionText = if offer.status == "Preview" then "N/A" else "LOADING..."
	local enabled = false
	if paidRandom and paidRandomAllowed ~= true then
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
	local style = if offer.kind == "GamePass" then "GamePass" else offer.definition.Type
	local badge = if offer.kind == "GamePass"
		then "GAMEPASS"
		else if offer.definition.Type == "Cash" then cashValueBadge(offer) else "DEVELOPER PRODUCT"
	local details = if offer.kind == "Product" and offer.definition.Type == "Cash"
		then `+{offer.definition.CashAmount} CASH  |  {offer.description}`
		else offer.description
	return {
		id = key,
		title = if offer.kind == "Product" and offer.definition.Type == "Cash"
			then offer.displayName
			else if state and state.title then state.title else offer.displayName,
		details = details,
		badge = badge,
		image = if state and state.image then state.image else "",
		style = style,
		actionText = actionText,
		actionEnabled = enabled,
		layoutOrder = order,
	}
end

-- Evaluated client-side because the offer grants nothing on its own: it only
-- decides how prominently an ordinary pass is merchandised. The purchase still
-- runs through the same server-verified game-pass prompt as every other offer.
local function starterOfferState(): any
	if activeStarterOffer == nil or activeGamePasses.StarterOffer == nil or currentData == nil then
		return nil
	end
	local config = activeGamePasses.StarterOffer
	local offer = offersByKey[`GamePass:{config.PassKey}`]
	if offer == nil then
		return nil
	end

	local ownsAny = false
	for key, state in states do
		if state.owned and offersByKey[key] ~= nil and offersByKey[key].kind == "GamePass" then
			ownsAny = true
			break
		end
	end
	local purchased = activeStarterOffer.hasPurchased(currentData.Receipts, ownsAny)
	local onboarding = currentData.Onboarding
	local state =
		activeStarterOffer.evaluate(config, if onboarding then onboarding.FirstJoinAt else nil, activeNow(), purchased)
	if not state.active then
		return nil
	end
	return { offer = offer, config = config, remaining = state.secondsRemaining }
end

-- Fired independently of the storefront being open: the sidebar badge is the
-- surface that has to tell a player the offer exists before they think to look.
local function updateStarterSignal()
	local active = starterOfferState() ~= nil
	if active == starterActive then
		return
	end
	starterActive = active
	for _, listener in starterListeners do
		pcall(listener, active)
	end
end

local function renderStarterOffer()
	if nodes == nil or nodes.starterSection == nil then
		return
	end
	local starter = starterOfferState()
	nodes.starterSection.Visible = starter ~= nil
	if starter == nil then
		return
	end

	local key = offerKey(starter.offer)
	local state = states[key]
	nodes.starterHeadline.Text = string.upper(starter.offer.displayName)
	nodes.starterDetail.Text = starter.offer.description
	nodes.starterTimer.Text = `ENDS IN {activeStarterOffer.formatRemaining(starter.remaining)}`

	local actionText = "COMING SOON"
	local enabled = false
	if starter.offer.status == "Active" then
		if state == nil or not state.loaded then
			actionText = "LOADING..."
		elseif state.owned then
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
	local handle = activeButtonElement.mount(nodes.starterActionMount, {
		text = actionText,
		name = "StarterAction",
		activated = function()
			purchaseOffer(key)
		end,
	})
	fillMount(handle)
	handle:setEnabled(enabled)
	table.insert(cardHandles, handle)
end

render = function()
	destroyHandles(cardHandles)
	if nodes and nodes.cashLabel then
		nodes.cashLabel.Text = if currentData then `Cash: {currentData.Cash or 0}` else "Cash: loading"
	end
	updateStarterSignal()
	if not viewOpen or nodes == nil then
		return
	end
	if currentData == nil then
		setStatus("Economy data is loading.")
		return
	end
	if statusMessage == "Economy data is loading." then
		setStatus(
			if paidRandomAllowed == false
				then "Paid random items are unavailable in your region."
				else "Browse a section or inspect a crate."
		)
	end

	renderStarterOffer()

	local ids = sortedCrateIds()
	local featuredId = if nodes.featuredMount then featuredCrateId(ids) else nil
	if nodes.featuredTitle and activeFeaturedRotation ~= nil and activeShop ~= nil then
		local remaining = activeFeaturedRotation.secondsUntilRotation(activeShop.Featured, activeNow())
		nodes.featuredTitle.Text = `FEATURED  |  NEW DROP IN {activeStarterOffer.formatRemaining(remaining)}`
	end
	local function mountCrate(crateId: string, parent: Instance, isFeatured: boolean, order: number)
		local crate = activeCrates[crateId]
		local presentation = presentationFor(crate)
		local price = cashPriceFor(crateId)
		local discounted = price ~= nil and crate.CashPrice ~= nil and price < crate.CashPrice
		local cash = currentData.Cash or 0
		local cashBusy = busy[`Cash:{crateId}`] == true
		local product = crateProducts[crateId]
		local productKey = product and offerKey(product)
		local productState = productKey and states[productKey]
		local robuxText = "N/A"
		local robuxEnabled = false
		if product and product.status == "Active" then
			if paidRandomAllowed ~= true then
				robuxText = if paidRandomAllowed == nil then "CHECKING..." else "REGION LOCKED"
			elseif productState and productState.loaded and productState.forSale then
				robuxText = if busy[productKey] then "WAITING..." else `R$ {productState.price}`
				robuxEnabled = not busy[productKey] and #presentation.outcomes > 0
			elseif productState and productState.error then
				robuxText = "UNAVAILABLE"
			else
				robuxText = "LOADING..."
			end
		end
		local handle = activeCrateElement.mount(parent, {
			data = {
				id = crateId,
				title = crate.DisplayName or crateId,
				highlight = if discounted
					then `{presentation.highlight}  |  {activeShop.Featured.DiscountPercent}% OFF`
					else presentation.highlight,
				odds = presentation.odds,
				cashActionText = if cashBusy then "OPENING..." else if price then `{price} CASH` else "N/A",
				cashActionEnabled = price ~= nil
					and cash >= price
					and not cashBusy
					and paidRandomAllowed == true
					and #presentation.outcomes > 0,
				robuxActionText = robuxText,
				robuxActionEnabled = robuxEnabled,
				detailsActionText = "VIEW ODDS",
				layoutOrder = order,
				featured = isFeatured,
			},
			activated = actionForCrate,
		})
		if handle.instance and isFeatured then
			handle.instance.Size = UDim2.fromScale(1, 1)
		end
		table.insert(cardHandles, handle)
	end
	if featuredId and nodes.featuredMount then
		mountCrate(featuredId, nodes.featuredMount, true, 0)
	end
	if nodes.cratesHolder then
		for order, crateId in ids do
			mountCrate(crateId, nodes.cratesHolder, false, order)
		end
	end

	local cashOrder = 0
	local passOrder = 0
	for _, offer in offers do
		if offer.kind == "Product" and offer.definition.Type == "Cash" and nodes.cashOffersHolder then
			cashOrder += 1
			local handle = activeOfferElement.mount(nodes.cashOffersHolder, {
				data = offerData(offer, cashOrder),
				activated = purchaseOffer,
			})
			table.insert(cardHandles, handle)
		elseif offer.kind == "GamePass" and nodes.passesHolder then
			passOrder += 1
			local handle = activeOfferElement.mount(nodes.passesHolder, {
				data = offerData(offer, passOrder),
				activated = purchaseOffer,
			})
			table.insert(cardHandles, handle)
		end
	end

	if nodes.directHolder and activeDirectPurchase then
		local owned = currentData.Cosmetics and currentData.Cosmetics.Owned or {}
		local cash = currentData.Cash or 0
		local order = 0
		for _, entry in activeDirectPurchase.catalog(activeCosmetics.Items, activeCosmetics.Rarities) do
			if owned[entry.itemId] ~= true then
				order += 1
				local item = activeCosmetics.Items[entry.itemId]
				local key = `Direct:{entry.itemId}`
				local affordable = cash >= entry.price
				local handle = activeDirectElement.mount(nodes.directHolder, {
					data = {
						id = entry.itemId,
						title = item.DisplayName,
						details = `{string.upper(entry.rarity)}  |  GUARANTEED, NO RANDOM ROLL`,
						rarity = entry.rarity,
						state = if affordable then "Available" else "Default",
						actionText = if busy[key]
							then "BUYING..."
							else if affordable then `{entry.price} CASH` else `NEED {entry.price - cash} MORE`,
						actionEnabled = affordable and not busy[key],
						layoutOrder = order,
					},
					activated = purchaseCosmetic,
				})
				table.insert(cardHandles, handle)
			end
		end
	end
end

local function loadOffer(offer: any)
	if offer.status ~= "Active" or type(offer.id) ~= "number" then
		return
	end
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

local function findByPlatformId(kind: string, platformId: number): any?
	for _, offer in offers do
		if offer.kind == kind and offer.id == platformId then
			return offer
		end
	end
	return nil
end

local function connectMarketplaceSignals()
	table.insert(
		connections,
		activeMarketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if player ~= activePlayer then
				return
			end
			local offer = findByPlatformId("GamePass", passId)
			if offer == nil then
				return
			end
			local key = offerKey(offer)
			busy[key] = nil
			if purchased then
				setStatus("Purchase confirmed. Applying permanent cosmetics...")
			else
				setStatus("Purchase canceled.")
				report("PromptClosed", offer)
			end
			render()
		end)
	)
	table.insert(
		connections,
		activeMarketplace.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
			if activePlayer == nil or userId ~= activePlayer.UserId then
				return
			end
			local offer = findByPlatformId("Product", productId)
			if offer == nil then
				return
			end
			busy[offerKey(offer)] = nil
			if purchased then
				setStatus("Purchase submitted. Waiting for Roblox to grant it...")
			else
				setStatus("Purchase canceled.")
				report("PromptClosed", offer)
			end
			render()
		end)
	)
end

local function handleGrant(payload: any)
	local grantId = payload and payload.grantId
	if type(grantId) ~= "string" or seenGrantIds[grantId] then
		return
	end
	seenGrantIds[grantId] = true
	if payload.kind == "Cash" then
		setStatus(`Added {payload.amount or 0} Cash.`)
	elseif payload.kind == "GamePass" then
		local offer = findByPlatformId("GamePass", payload.passId)
		if offer then
			local state = states[offerKey(offer)]
			if state then
				state.owned = true
			end
			busy[offerKey(offer)] = nil
		end
		setStatus("Gamepass unlocked.")
	end
	render()
end

local function jumpTo(section: GuiObject)
	if nodes == nil or nodes.storefront == nil then
		return
	end
	local storefront = nodes.storefront :: ScrollingFrame
	local offset = section.AbsolutePosition.Y - storefront.AbsolutePosition.Y + storefront.CanvasPosition.Y
	storefront.CanvasPosition = Vector2.new(0, math.max(0, offset))
	report("ShopSectionViewed", { key = section.Name, kind = "Section" })
end

local function connectViewActions()
	if nodes.closeButton and nodes.closeButton:IsA("GuiButton") then
		table.insert(
			connections,
			nodes.closeButton.Activated:Connect(function()
				activeMenuManager.close("Api")
			end)
		)
	end
	local mappings = {
		FeaturedTab = nodes.featuredSection,
		CratesTab = nodes.cratesSection,
		DirectTab = nodes.directSection,
		CashTab = nodes.cashSection,
		PassesTab = nodes.passesSection,
	}
	for name, section in mappings do
		local button = nodes.jumpTabs and nodes.jumpTabs:WaitForChild(name)
		if button and button:IsA("GuiButton") then
			table.insert(
				connections,
				button.Activated:Connect(function()
					jumpTo(section)
				end)
			)
		end
	end
end

local function hasActivePaidRandomOffer(): boolean
	for _, offer in offers do
		if
			offer.status == "Active"
			and offer.kind == "Product"
			and (offer.definition.Type == "Cash" or offer.definition.Type == "Crate")
		then
			return true
		end
	end
	return false
end

function ShopController.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeStore = if options and options.store then options.store else EconomyStore
	activeNetwork = if options and options.network
		then options.network
		else require(replicatedStorage():WaitForChild("Shared"):WaitForChild("Network"))
	activeMenuManager = if options and options.menuManager
		then options.menuManager
		else require(script.Parent.MenuManager)
	activeCrateElement = if options and options.crateElement
		then options.crateElement
		else if options and options.itemElement then options.itemElement else CrateCardElement
	activeOfferElement = if options and options.offerElement then options.offerElement else StoreOfferCardElement
	activeDirectElement = if options and options.directElement then options.directElement else EconomyItemElement
	activeDirectPurchase = require(
		replicatedStorage()
			:WaitForChild("Shared")
			:WaitForChild("Game")
			:WaitForChild("Economy")
			:WaitForChild("DirectPurchase")
	)
	activeButtonElement = if options and options.buttonElement then options.buttonElement else ButtonElement
	activeCrates = if options and options.crates then options.crates else resolveDependency("Crates")
	activeCosmetics = if options and options.cosmetics then options.cosmetics else resolveDependency("Cosmetics")
	activeProducts = if options and options.products then options.products else resolveDependency("Products")
	activeGamePasses = if options and options.gamePasses then options.gamePasses else resolveDependency("GamePasses")
	activeStoreCatalog = if options and options.storeCatalog then options.storeCatalog else resolveStoreCatalog()
	activeRunAsync = if options and options.runAsync then options.runAsync else runAsyncDefault
	activeWait = if options and options.wait then options.wait else waitDefault
	activeNow = if options and options.now
		then options.now
		else function()
			return os.time()
		end
	activeShop = if options and options.shop then options.shop else resolveDependency("Shop")
	activeFeaturedRotation = require(
		replicatedStorage()
			:WaitForChild("Shared")
			:WaitForChild("Game")
			:WaitForChild("Economy")
			:WaitForChild("FeaturedRotation")
	)
	activeStarterOffer = require(
		replicatedStorage()
			:WaitForChild("Shared")
			:WaitForChild("Game")
			:WaitForChild("Economy")
			:WaitForChild("StarterOffer")
	)
	offers = activeStoreCatalog.build(activeGamePasses.Catalog, activeProducts.Catalog)
	for _, offer in offers do
		local key = offerKey(offer)
		offersByKey[key] = offer
		if offer.kind == "Product" and offer.definition.Type == "Crate" then
			crateProducts[offer.definition.CrateId] = offer
		end
	end

	if options and options.viewNodes then
		nodes = options.viewNodes
	elseif options and (options.cratesHolder or options.holder) and options.cashLabel and options.statusLabel then
		nodes = {
			cratesHolder = options.cratesHolder or options.holder,
			featuredMount = options.featuredMount,
			cashOffersHolder = options.cashOffersHolder,
			passesHolder = options.passesHolder,
			directHolder = options.directHolder,
			cashLabel = options.cashLabel,
			statusLabel = options.statusLabel,
		}
	else
		nodes = resolveView()
	end

	viewOpen = activeMenuManager.isOpen("Shop")
	if hasActivePaidRandomOffer() then
		activePaidRandomPolicy = if options and options.paidRandomPolicy
			then options.paidRandomPolicy
			else require(script.Parent.PaidRandomPolicyStore)
		activePaidRandomPolicy.start()
		paidRandomAllowed = activePaidRandomPolicy.snapshot()
		policyDisconnect = activePaidRandomPolicy.onChanged(function(allowed)
			paidRandomAllowed = allowed
			if not allowed then
				closeDetails()
				setStatus("Paid random items are unavailable in your region.")
			end
			render()
		end)
	else
		paidRandomAllowed = true
	end

	activeStore.start()
	currentData = activeStore.snapshot()
	storeDisconnect = activeStore.onChanged(function(data)
		currentData = data
		render()
	end)
	activeNetwork.on("CrateOpened", showReveal)
	activeNetwork.on("StorePurchaseGranted", handleGrant)
	menuDisconnect = activeMenuManager.onChanged(function(newMenu: string?)
		viewOpen = newMenu == "Shop"
		if not viewOpen then
			closeDetails()
			if nodes and nodes.revealOverlay then
				nodes.revealOverlay.Visible = false
			end
		end
		render()
	end)
	if nodes.view then
		connectViewActions()
	end

	local hasActiveOffer = false
	for _, offer in offers do
		if offer.status == "Active" and type(offer.id) == "number" then
			hasActiveOffer = true
			break
		end
	end
	if hasActiveOffer then
		activeMarketplace = if options and options.marketplace
			then options.marketplace
			else game:GetService("MarketplaceService")
		activePlayer = if options and options.player then options.player else game:GetService("Players").LocalPlayer
		connectMarketplaceSignals()
		for _, offer in offers do
			activeRunAsync(function()
				loadOffer(offer)
			end)
		end
	end
	render()
end

function ShopController.onStarterOfferChanged(callback: (active: boolean) -> ()): () -> ()
	table.insert(starterListeners, callback)
	pcall(callback, starterActive)
	return function()
		local index = table.find(starterListeners, callback)
		if index then
			table.remove(starterListeners, index)
		end
	end
end

function ShopController._resetForTest()
	if storeDisconnect then
		storeDisconnect()
	end
	if menuDisconnect then
		menuDisconnect()
	end
	if policyDisconnect then
		policyDisconnect()
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	destroyHandles(cardHandles)
	destroyHandles(modalHandles)
	started = false
	activeStore = EconomyStore
	activeNetwork = nil
	activeMenuManager = nil
	activeCrateElement = CrateCardElement
	activeOfferElement = StoreOfferCardElement
	activeDirectElement = EconomyItemElement
	activeDirectPurchase = nil
	activeStarterOffer = nil
	activeFeaturedRotation = nil
	activeShop = nil
	table.clear(starterListeners)
	starterActive = false
	activeButtonElement = ButtonElement
	activeCrates = nil
	activeCosmetics = nil
	activeProducts = nil
	activeGamePasses = nil
	activeStoreCatalog = nil
	activePaidRandomPolicy = nil
	activeMarketplace = nil
	activePlayer = nil
	activeRunAsync = runAsyncDefault
	activeWait = waitDefault
	nodes = nil
	currentData = nil
	table.clear(offers)
	table.clear(offersByKey)
	table.clear(crateProducts)
	table.clear(states)
	table.clear(busy)
	table.clear(connections)
	table.clear(seenOpenIds)
	table.clear(seenOpenOrder)
	table.clear(seenGrantIds)
	viewOpen = false
	storeDisconnect = nil
	menuDisconnect = nil
	policyDisconnect = nil
	statusMessage = "Economy data is loading."
	paidRandomAllowed = true
	detailSelection = nil
	revealGeneration = 0
	if activeRevealTween then
		activeRevealTween:Cancel()
		activeRevealTween = nil
	end
end

return ShopController
