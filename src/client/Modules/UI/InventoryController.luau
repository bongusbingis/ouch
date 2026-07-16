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
	if statusLabel then
		statusLabel.Text = message
	end
end

local function sortedOwnedIds(): { string }
	local ids = {}
	local owned = currentData.Cosmetics.Owned
	for itemId, isOwned in owned do
		if isOwned and activeCosmetics.Items[itemId] then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids, function(left, right)
		local leftItem = activeCosmetics.Items[left]
		local rightItem = activeCosmetics.Items[right]
		if leftItem.Category ~= rightItem.Category then
			return leftItem.Category < rightItem.Category
		end
		if leftItem.DisplayName ~= rightItem.DisplayName then
			return leftItem.DisplayName < rightItem.DisplayName
		end
		return left < right
	end)
	return ids
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

local function toggleEquip(itemId: string)
	if busy[itemId] or currentData == nil then
		return
	end
	local item = activeCosmetics.Items[itemId]
	if item == nil then
		return
	end
	local equipped = currentData.Cosmetics.Equipped[item.Category] == itemId
	busy[itemId] = true
	setStatus(if equipped then "Unequipping item..." else "Equipping item...")
	render()

	activeRunAsync(function()
		local callOk, accepted, reason =
			pcall(activeNetwork.call, "EquipCosmetic", item.Category, if equipped then nil else itemId)
		busy[itemId] = nil
		if not callOk then
			setStatus("Equip failed: network error.")
		elseif not accepted then
			setStatus(errorMessage(reason))
		else
			setStatus(if equipped then `Unequipped {item.DisplayName}.` else `Equipped {item.DisplayName}.`)
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

	local ids = sortedOwnedIds()
	if #ids == 0 then
		setStatus("No owned items.")
		return
	end
	for order, itemId in ids do
		local item = activeCosmetics.Items[itemId]
		local equipped = currentData.Cosmetics.Equipped[item.Category] == itemId
		table.insert(
			handles,
			activeItemElement.mount(holder, {
				data = {
					id = itemId,
					title = item.DisplayName,
					details = `Category: {item.Category}  Rarity: {item.Rarity}`,
					state = if equipped then "Equipped" else "Owned",
					actionText = if equipped then "Unequip" else "Equip",
					actionEnabled = not busy[itemId],
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
end

return InventoryController
