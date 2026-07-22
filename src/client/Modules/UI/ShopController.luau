--!strict

-- Cash-crate storefront. Merchandising copy derives from configured pools;
-- purchases still route only through the authoritative OpenCrate remote.

local CrateCardElement = require(script.Parent.Elements.CrateCardElement)
local CratePresentation = require(script.Parent.CratePresentation)
local EconomyStore = require(script.Parent.EconomyStore)

type StartOptions = {
	store: any?,
	network: any?,
	menuManager: any?,
	itemElement: any?,
	crateElement: any?,
	crates: any?,
	cosmetics: any?,
	holder: ScrollingFrame?,
	featuredMount: Frame?,
	cashLabel: TextLabel?,
	statusLabel: TextLabel?,
	runAsync: ((callback: () -> ()) -> ())?,
}

local ShopController = {}

local started = false
local holder: ScrollingFrame? = nil
local featuredMount: Frame? = nil
local cashLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local activeStore: any = EconomyStore
local activeNetwork: any = nil
local activeMenuManager: any = nil
local activeCrateElement: any = CrateCardElement
local activeCrates: any = nil
local activeCosmetics: any = nil
local function runAsyncDefault(callback: () -> ())
	if task then
		task.spawn(callback)
	else
		callback()
	end
end
local activeRunAsync: (callback: () -> ()) -> () = runAsyncDefault
local currentData: any = nil
local handles: { any } = {}
local busy: { [string]: boolean } = {}
local viewOpen = false
local storeDisconnect: (() -> ())? = nil
local menuDisconnect: (() -> ())? = nil
local statusMessage = "Economy data is loading."

local function replicatedStorage(): ReplicatedStorage
	return game:GetService("ReplicatedStorage")
end

local function resolveNetwork(): any
	return require(replicatedStorage():WaitForChild("Shared"):WaitForChild("Network"))
end

local function resolveCrates(): any
	return require(replicatedStorage():WaitForChild("Config"):WaitForChild("Crates"))
end

local function resolveCosmetics(): any
	return require(replicatedStorage():WaitForChild("Config"):WaitForChild("Cosmetics"))
end

local function resolveMenuManager(): any
	return require(script.Parent.MenuManager)
end

local function resolveView(): (ScrollingFrame, Frame, TextLabel, TextLabel)
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local view = playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("Shop")
	assert(view:IsA("CanvasGroup"), "[ShopController] Views.Shop must be a CanvasGroup")
	local holderInstance = view:WaitForChild("Holder")
	local featuredInstance = view:WaitForChild("FeaturedMount")
	local cashInstance = view:WaitForChild("Cash")
	local statusInstance = view:WaitForChild("Status")
	assert(holderInstance:IsA("ScrollingFrame"), "[ShopController] Views.Shop.Holder must be a ScrollingFrame")
	assert(featuredInstance:IsA("Frame"), "[ShopController] Views.Shop.FeaturedMount must be a Frame")
	assert(cashInstance:IsA("TextLabel"), "[ShopController] Views.Shop.Cash must be a TextLabel")
	assert(statusInstance:IsA("TextLabel"), "[ShopController] Views.Shop.Status must be a TextLabel")
	return holderInstance, featuredInstance, cashInstance, statusInstance
end

local function destroyItems()
	for _, handle in handles do
		handle:destroy()
	end
	table.clear(handles)
end

local function setStatus(message: string)
	statusMessage = message
	if statusLabel then
		statusLabel.Text = message
	end
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

local function resultMessage(result: any): string
	local item = result and activeCosmetics.Items[result.itemId]
	local displayName = if item then item.DisplayName else (result and result.itemId) or "Unknown item"
	if result and result.isDupe then
		return `Duplicate {displayName}; refunded {result.cashRefund or 0} Cash.`
	end
	return `Opened {displayName}.`
end

local function presentationFor(crate: any): any
	if activeCosmetics.Rarities == nil then
		return {
			highlight = `{#crate.ItemPool} COSMETICS INSIDE`,
			odds = "ODDS SHOWN BEFORE PURCHASE",
			rarityCount = 0,
		}
	end
	return CratePresentation.forCrate(crate, activeCosmetics)
end

local function featuredCrateId(ids: { string }): string?
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

local function errorMessage(reason: any): string
	if reason == "insufficient_cash" then
		return "Not enough Cash."
	elseif reason == "rate_limited" then
		return "Please wait before opening another crate."
	elseif reason == "no_profile" then
		return "Economy data is still loading."
	elseif reason == "invalid_crate" then
		return "This crate is unavailable."
	end
	return `Open failed: {tostring(reason or "unknown error")}`
end

local render: () -> ()

local function openCrate(crateId: string)
	if busy[crateId] then
		return
	end
	busy[crateId] = true
	setStatus("Opening crate...")
	render()

	activeRunAsync(function()
		local callOk, result, reason = pcall(activeNetwork.call, "OpenCrate", crateId)
		busy[crateId] = nil
		if not callOk then
			setStatus("Open failed: network error.")
		elseif result == nil then
			setStatus(errorMessage(reason))
		else
			setStatus(resultMessage(result))
		end
		render()
	end)
end

render = function()
	destroyItems()
	local cash = if currentData then currentData.Cash or 0 else nil
	if cashLabel then
		cashLabel.Text = if cash ~= nil then `Cash: {cash}` else "Cash: loading"
	end
	if not viewOpen or holder == nil then
		return
	end
	if currentData == nil then
		setStatus("Economy data is loading.")
		return
	end
	if statusMessage == "Economy data is loading." then
		setStatus("Select a crate to open.")
	end

	local ids = sortedCrateIds()
	if #ids == 0 then
		setStatus("No crates are configured.")
		return
	end
	local featuredId = if featuredMount then featuredCrateId(ids) else nil
	for order, crateId in ids do
		local crate = activeCrates[crateId]
		local price = crate.CashPrice
		local actionText = if price then `Open - {price} Cash` else "Cash purchase unavailable"
		local presentation = presentationFor(crate)
		local isFeatured = crateId == featuredId
		local parent = if isFeatured then featuredMount else holder
		local handle = activeCrateElement.mount(parent, {
			data = {
				id = crateId,
				title = crate.DisplayName or crateId,
				highlight = presentation.highlight,
				odds = presentation.odds,
				actionText = if busy[crateId] then "Opening..." else actionText,
				actionEnabled = price ~= nil and not busy[crateId],
				layoutOrder = order,
				featured = isFeatured,
			},
			activated = openCrate,
		})
		if handle.instance then
			handle.instance.Size = if isFeatured then UDim2.fromScale(1, 1) else UDim2.fromScale(0.94, 0.94)
		end
		table.insert(handles, handle)
	end
end

local function setOpen(isOpen: boolean)
	if viewOpen == isOpen then
		return
	end
	viewOpen = isOpen
	render()
end

function ShopController.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeStore = if options and options.store then options.store else EconomyStore
	activeNetwork = if options and options.network then options.network else resolveNetwork()
	activeMenuManager = if options and options.menuManager then options.menuManager else resolveMenuManager()
	activeCrateElement = if options and options.crateElement
		then options.crateElement
		else if options and options.itemElement then options.itemElement else CrateCardElement
	activeCrates = if options and options.crates then options.crates else resolveCrates()
	activeCosmetics = if options and options.cosmetics then options.cosmetics else resolveCosmetics()
	activeRunAsync = if options and options.runAsync then options.runAsync else runAsyncDefault

	if options and options.holder and options.cashLabel and options.statusLabel then
		holder = options.holder
		featuredMount = options.featuredMount
		cashLabel = options.cashLabel
		statusLabel = options.statusLabel
	else
		holder, featuredMount, cashLabel, statusLabel = resolveView()
	end

	activeStore.start()
	currentData = activeStore.snapshot()
	storeDisconnect = activeStore.onChanged(function(data)
		currentData = data
		render()
	end)
	activeNetwork.on("CrateOpened", function(result)
		setStatus(resultMessage(result))
	end)
	menuDisconnect = activeMenuManager.onChanged(function(newMenu: string?)
		setOpen(newMenu == "Shop")
	end)
	viewOpen = activeMenuManager.isOpen("Shop")
	render()
end

function ShopController._resetForTest()
	if storeDisconnect then
		storeDisconnect()
	end
	if menuDisconnect then
		menuDisconnect()
	end
	destroyItems()
	started = false
	holder = nil
	featuredMount = nil
	cashLabel = nil
	statusLabel = nil
	activeStore = EconomyStore
	activeNetwork = nil
	activeMenuManager = nil
	activeCrateElement = CrateCardElement
	activeCrates = nil
	activeCosmetics = nil
	activeRunAsync = runAsyncDefault
	currentData = nil
	table.clear(busy)
	viewOpen = false
	storeDisconnect = nil
	menuDisconnect = nil
	statusMessage = "Economy data is loading."
end

return ShopController
