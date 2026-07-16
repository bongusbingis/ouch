--!strict

-- PROTOTYPE: Functional, unstyled cosmetic inventory. Owned/equipped profile
-- data is read from Replica; equip mutations use the authoritative remote.

local EconomyItemElement = require(script.Parent.Elements.EconomyItemElement)
local EconomyPrototypeLayout = require(script.Parent.EconomyPrototypeLayout)
local EconomyStore = require(script.Parent.EconomyStore)

type StartOptions = {
	store: any?,
	network: any?,
	menuManager: any?,
	itemElement: any?,
	cosmetics: any?,
	holder: ScrollingFrame?,
	statusLabel: TextLabel?,
	runAsync: ((callback: () -> ()) -> ())?,
}

type InventoryEntry = {
	id: string,
	itemId: string?,
	category: string,
	displayName: string,
	rarity: string,
	isDefault: boolean,
}

local InventoryController = {}

local started = false
local holder: ScrollingFrame? = nil
local statusLabel: TextLabel? = nil
local activeStore: any = EconomyStore
local activeNetwork: any = nil
local activeMenuManager: any = nil
local activeItemElement: any = EconomyItemElement
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
local statusMessage = "Inventory data is loading."

local function replicatedStorage(): ReplicatedStorage
	return game:GetService("ReplicatedStorage")
end

local function resolveNetwork(): any
	return require(replicatedStorage():WaitForChild("Shared"):WaitForChild("Network"))
end

local function resolveCosmetics(): any
	return require(replicatedStorage():WaitForChild("Config"):WaitForChild("Cosmetics"))
end

local function resolveMenuManager(): any
	return require(script.Parent.MenuManager)
end

local function resolveView(): (ScrollingFrame, TextLabel)
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local view =
		playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("Inventory")
	assert(view:IsA("GuiObject"), "[InventoryController] Views.Inventory must be a GuiObject")
	EconomyPrototypeLayout.applyInventory(view)
	local holderInstance = view:WaitForChild("Holder")
	local statusInstance = view:WaitForChild("Status")
	assert(
		holderInstance:IsA("ScrollingFrame"),
		"[InventoryController] Views.Inventory.Holder must be a ScrollingFrame"
	)
	assert(statusInstance:IsA("TextLabel"), "[InventoryController] Views.Inventory.Status must be a TextLabel")
	return holderInstance, statusInstance
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

local function sortedEntries(): { InventoryEntry }
	local entries = {}
	for category, defaultItem in activeCosmetics.Defaults or {} do
		table.insert(entries, {
			id = `Default_{category}`,
			itemId = nil,
			category = category,
			displayName = defaultItem.DisplayName,
			rarity = "Default",
			isDefault = true,
		})
	end
	local owned = currentData.Cosmetics.Owned
	for itemId, isOwned in owned do
		local item = activeCosmetics.Items[itemId]
		if isOwned and item then
			table.insert(entries, {
				id = itemId,
				itemId = itemId,
				category = item.Category,
				displayName = item.DisplayName,
				rarity = item.Rarity,
				isDefault = false,
			})
		end
	end
	table.sort(entries, function(left, right)
		if left.category ~= right.category then
			return left.category < right.category
		end
		if left.isDefault ~= right.isDefault then
			return left.isDefault
		end
		if left.displayName ~= right.displayName then
			return left.displayName < right.displayName
		end
		return left.id < right.id
	end)
	return entries
end

local function entryForId(entryId: string): InventoryEntry?
	for _, entry in sortedEntries() do
		if entry.id == entryId then
			return entry
		end
	end
	return nil
end

local function errorMessage(reason: any): string
	if reason == "rate_limited" then
		return "Please wait before changing another item."
	elseif reason == "no_profile" then
		return "Inventory data is still loading."
	elseif reason == "not_owned" then
		return "That item is not owned."
	elseif reason == "wrong_slot" or reason == "invalid_slot" then
		return "That item cannot be equipped in this slot."
	end
	return `Equip failed: {tostring(reason or "unknown error")}`
end

local render: () -> ()

local function toggleEquip(entryId: string)
	if busy[entryId] or currentData == nil then
		return
	end
	local entry = entryForId(entryId)
	if entry == nil then
		return
	end
	local equippedId = currentData.Cosmetics.Equipped[entry.category]
	local equipped = if entry.isDefault then equippedId == nil or equippedId == "" else equippedId == entry.itemId
	if entry.isDefault and equipped then
		return
	end
	local nextItemId = if entry.isDefault or equipped then nil else entry.itemId
	busy[entryId] = true
	setStatus(if nextItemId == nil then "Equipping default item..." else "Equipping item...")
	render()

	activeRunAsync(function()
		local callOk, accepted, reason = pcall(activeNetwork.call, "EquipCosmetic", entry.category, nextItemId)
		busy[entryId] = nil
		if not callOk then
			setStatus("Equip failed: network error.")
		elseif not accepted then
			setStatus(errorMessage(reason))
		else
			local defaultItem = (activeCosmetics.Defaults or {})[entry.category]
			local equippedName = if nextItemId == nil and defaultItem
				then defaultItem.DisplayName
				else entry.displayName
			setStatus(`Equipped {equippedName}.`)
		end
		render()
	end)
end

render = function()
	destroyItems()
	if not viewOpen or holder == nil then
		return
	end
	if currentData == nil then
		setStatus("Inventory data is loading.")
		return
	end
	if statusMessage == "Inventory data is loading." then
		setStatus("Select an item to equip.")
	end

	local entries = sortedEntries()
	if #entries == 0 then
		setStatus("No owned items.")
		return
	end
	for order, entry in entries do
		local equippedId = currentData.Cosmetics.Equipped[entry.category]
		local equipped = if entry.isDefault then equippedId == nil or equippedId == "" else equippedId == entry.itemId
		table.insert(
			handles,
			activeItemElement.mount(holder, {
				data = {
					id = entry.id,
					title = entry.displayName,
					details = `Category: {entry.category}  Rarity: {entry.rarity}`,
					state = if equipped then "Equipped" else if entry.isDefault then "Available" else "Owned",
					actionText = if equipped
						then if entry.isDefault then "Equipped" else "Use Default"
						else if entry.isDefault then "Use Default" else "Equip",
					actionEnabled = not busy[entry.id] and not (entry.isDefault and equipped),
					layoutOrder = order,
				},
				activated = toggleEquip,
			})
		)
	end
end

local function setOpen(isOpen: boolean)
	if viewOpen == isOpen then
		return
	end
	viewOpen = isOpen
	render()
end

function InventoryController.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeStore = if options and options.store then options.store else EconomyStore
	activeNetwork = if options and options.network then options.network else resolveNetwork()
	activeMenuManager = if options and options.menuManager then options.menuManager else resolveMenuManager()
	activeItemElement = if options and options.itemElement then options.itemElement else EconomyItemElement
	activeCosmetics = if options and options.cosmetics then options.cosmetics else resolveCosmetics()
	activeRunAsync = if options and options.runAsync then options.runAsync else runAsyncDefault

	if options and options.holder and options.statusLabel then
		holder = options.holder
		statusLabel = options.statusLabel
	else
		holder, statusLabel = resolveView()
	end

	activeStore.start()
	currentData = activeStore.snapshot()
	storeDisconnect = activeStore.onChanged(function(data)
		currentData = data
		render()
	end)
	menuDisconnect = activeMenuManager.onChanged(function(newMenu: string?)
		setOpen(newMenu == "Inventory")
	end)
	viewOpen = activeMenuManager.isOpen("Inventory")
	render()
end

function InventoryController._resetForTest()
	if storeDisconnect then
		storeDisconnect()
	end
	if menuDisconnect then
		menuDisconnect()
	end
	destroyItems()
	started = false
	holder = nil
	statusLabel = nil
	activeStore = EconomyStore
	activeNetwork = nil
	activeMenuManager = nil
	activeItemElement = EconomyItemElement
	activeCosmetics = nil
	activeRunAsync = runAsyncDefault
	currentData = nil
	table.clear(busy)
	viewOpen = false
	storeDisconnect = nil
	menuDisconnect = nil
	statusMessage = "Inventory data is loading."
end

return InventoryController
