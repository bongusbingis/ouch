--!strict

-- Cosmetic inventory. Owned/equipped profile data is read from Replica;
-- equip mutations use the authoritative remote.

local EconomyItemElement = require(script.Parent.Elements.EconomyItemElement)
local EconomyStore = require(script.Parent.EconomyStore)
local dataModel: any = script
while dataModel.Parent do
	dataModel = dataModel.Parent
end
local replicatedStorageInstance = dataModel:WaitForChild("ReplicatedStorage")
local InventoryModel = require(
	replicatedStorageInstance
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Economy")
		:WaitForChild("InventoryModel")
)

type StartOptions = {
	store: any?,
	network: any?,
	menuManager: any?,
	itemElement: any?,
	cosmetics: any?,
	holder: ScrollingFrame?,
	statusLabel: TextLabel?,
	tabs: { [string]: TextButton }?,
	tabLabels: { [string]: TextLabel }?,
	categoryTitle: TextLabel?,
	itemCount: TextLabel?,
	emptyLabel: TextLabel?,
	runAsync: ((callback: () -> ()) -> ())?,
}

type InventoryEntry = InventoryModel.Entry

local CATEGORY_ORDER = { "BallAssets", "HammerAssets", "TrailAssets", "CostumeAssets", "EmoteAssets" }
local CATEGORY_LABELS = {
	BallAssets = "BALLS",
	HammerAssets = "HAMMERS",
	TrailAssets = "TRAILS",
	CostumeAssets = "OUTFITS",
	EmoteAssets = "EMOTES",
}
local CATEGORY_TITLES = {
	BallAssets = "DODGEBALLS",
	HammerAssets = "HAMMERS",
	TrailAssets = "TRAIL EFFECTS",
	CostumeAssets = "OUTFITS",
	EmoteAssets = "EMOTES",
}

local InventoryController = {}

local started = false
local holder: ScrollingFrame? = nil
local statusLabel: TextLabel? = nil
local tabButtons: { [string]: TextButton } = {}
local tabLabels: { [string]: TextLabel } = {}
local categoryTitle: TextLabel? = nil
local itemCount: TextLabel? = nil
local emptyLabel: TextLabel? = nil
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
local tabConnections: { any } = {}
local statusMessage = "Inventory data is loading."
local selectedCategory: string? = nil

local function replicatedStorage(): ReplicatedStorage
	return replicatedStorageInstance :: ReplicatedStorage
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

local function resolveView(): (
	ScrollingFrame,
	TextLabel,
	{ [string]: TextButton },
	{ [string]: TextLabel },
	TextLabel,
	TextLabel,
	TextLabel
)
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local view =
		playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("Inventory")
	assert(view:IsA("CanvasGroup"), "[InventoryController] Views.Inventory must be a CanvasGroup")
	local panel = view:WaitForChild("PanelBounds")
	assert(panel:IsA("Frame"), "[InventoryController] Views.Inventory.PanelBounds must be a Frame")
	local tabsInstance = panel:WaitForChild("Tabs")
	local content = panel:WaitForChild("ContentWell")
	assert(tabsInstance:IsA("Frame"), "[InventoryController] Views.Inventory.PanelBounds.Tabs must be a Frame")
	assert(content:IsA("Frame"), "[InventoryController] Views.Inventory.PanelBounds.ContentWell must be a Frame")
	local holderInstance = content:WaitForChild("Holder")
	local statusInstance = panel:WaitForChild("Status")
	local categoryTitleInstance = content:WaitForChild("CategoryTitle")
	local itemCountInstance = content:WaitForChild("ItemCount")
	local emptyInstance = content:WaitForChild("Empty")
	assert(
		holderInstance:IsA("ScrollingFrame"),
		"[InventoryController] Views.Inventory.PanelBounds.ContentWell.Holder must be a ScrollingFrame"
	)
	assert(
		statusInstance:IsA("TextLabel"),
		"[InventoryController] Views.Inventory.PanelBounds.Status must be a TextLabel"
	)
	assert(categoryTitleInstance:IsA("TextLabel"), "[InventoryController] Inventory.CategoryTitle must be a TextLabel")
	assert(itemCountInstance:IsA("TextLabel"), "[InventoryController] Inventory.ItemCount must be a TextLabel")
	assert(emptyInstance:IsA("TextLabel"), "[InventoryController] Inventory.Empty must be a TextLabel")

	local buttons: { [string]: TextButton } = {}
	local labels: { [string]: TextLabel } = {}
	for _, category in CATEGORY_ORDER do
		local button = tabsInstance:WaitForChild(category)
		assert(button:IsA("TextButton"), `[InventoryController] Inventory.Tabs.{category} must be a TextButton`)
		local label = button:WaitForChild("Label")
		assert(label:IsA("TextLabel"), `[InventoryController] Inventory.Tabs.{category}.Label must be a TextLabel`)
		buttons[category] = button
		labels[category] = label
	end
	return holderInstance, statusInstance, buttons, labels, categoryTitleInstance, itemCountInstance, emptyInstance
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

local function sortedEntries(categoryFilter: string?): { InventoryEntry }
	return InventoryModel.entries(activeCosmetics, currentData.Cosmetics.Owned, categoryFilter)
end

local function availableCategories(): { string }
	return InventoryModel.categories(activeCosmetics, CATEGORY_ORDER)
end

local function categoryName(category: string): string
	return CATEGORY_LABELS[category] or string.upper(category:gsub("Assets$", ""))
end

local function entryForId(entryId: string): InventoryEntry?
	return InventoryModel.find(sortedEntries(nil), entryId)
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

local function setTabVisual(category: string, selected: boolean, count: number)
	local button = tabButtons[category]
	if button == nil then
		return
	end
	local light = if selected then Color3.fromRGB(191, 255, 91) else Color3.fromRGB(255, 245, 211)
	local dark = if selected then Color3.fromRGB(91, 194, 55) else Color3.fromRGB(218, 188, 125)
	button.BackgroundColor3 = light
	local gradient = button:WaitForChild("ColorWash")
	local outline = button:WaitForChild("Outline")
	assert(gradient:IsA("UIGradient"), `[InventoryController] Inventory.Tabs.{category}.ColorWash must be a UIGradient`)
	assert(outline:IsA("UIStroke"), `[InventoryController] Inventory.Tabs.{category}.Outline must be a UIStroke`)
	if ColorSequence ~= nil then
		gradient.Color = ColorSequence.new(light, dark)
	end
	outline.Color = if selected then Color3.fromRGB(47, 83, 34) else Color3.fromRGB(92, 70, 48)
	outline.Thickness = if selected then 3.5 else 2.5
	local label = tabLabels[category]
	if label then
		label.Text = `{categoryName(category)}  {count}`
		label.TextColor3 = if selected then Color3.fromRGB(34, 62, 29) else Color3.fromRGB(62, 47, 34)
	end
end

local function ensureSelectedCategory()
	local categories = availableCategories()
	if #categories == 0 then
		selectedCategory = nil
		return
	end
	for _, category in categories do
		if category == selectedCategory then
			return
		end
	end
	selectedCategory = categories[1]
end

local function selectCategory(category: string)
	if selectedCategory == category then
		return
	end
	for _, available in availableCategories() do
		if available == category then
			selectedCategory = category
			if currentData then
				setStatus("Select an item to equip.")
			end
			render()
			return
		end
	end
end

local function bindTabs()
	for category, button in tabButtons do
		table.insert(
			tabConnections,
			button.Activated:Connect(function()
				selectCategory(category)
			end)
		)
	end
end

local function toggleEquip(entryId: string)
	if busy[entryId] or currentData == nil then
		return
	end
	local entry = entryForId(entryId)
	if entry == nil then
		return
	end
	local equipped = InventoryModel.isEquipped(entry, currentData.Cosmetics.Equipped)
	if entry.isDefault and equipped then
		return
	end
	local nextItemId = InventoryModel.nextEquip(entry, currentData.Cosmetics.Equipped)
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

	ensureSelectedCategory()
	local allEntries = sortedEntries(nil)
	local counts: { [string]: number } = {}
	for _, entry in allEntries do
		counts[entry.category] = (counts[entry.category] or 0) + 1
	end
	local categories = availableCategories()
	for category, button in tabButtons do
		button.Visible = table.find(categories, category) ~= nil
		setTabVisual(category, category == selectedCategory, counts[category] or 0)
	end

	local category = selectedCategory
	if category == nil then
		if emptyLabel then
			emptyLabel.Visible = true
			emptyLabel.Text = "No inventory categories are configured."
		end
		return
	end
	local entries = sortedEntries(category)
	if categoryTitle then
		categoryTitle.Text = CATEGORY_TITLES[category] or categoryName(category)
	end
	if itemCount then
		itemCount.Text = `{#entries} {if #entries == 1 then "ITEM" else "ITEMS"}`
	end
	if emptyLabel then
		emptyLabel.Visible = #entries == 0
		emptyLabel.Text = `No owned {string.lower(categoryName(category))} yet.`
	end
	if #entries == 0 then
		return
	end
	for order, entry in entries do
		local equipped = InventoryModel.isEquipped(entry, currentData.Cosmetics.Equipped)
		table.insert(
			handles,
			activeItemElement.mount(holder, {
				data = {
					id = entry.id,
					title = entry.displayName,
					details = `{string.upper(entry.rarity)} COSMETIC`,
					rarity = entry.rarity,
					state = if equipped then "Equipped" else if entry.isDefault then "Default" else "Owned",
					actionText = if equipped
						then if entry.isDefault then "Equipped" else "Unequip"
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
		tabButtons = options.tabs or {}
		tabLabels = options.tabLabels or {}
		categoryTitle = options.categoryTitle
		itemCount = options.itemCount
		emptyLabel = options.emptyLabel
	else
		holder, statusLabel, tabButtons, tabLabels, categoryTitle, itemCount, emptyLabel = resolveView()
	end
	bindTabs()

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
	for _, connection in tabConnections do
		connection:Disconnect()
	end
	table.clear(tabConnections)
	destroyItems()
	started = false
	holder = nil
	statusLabel = nil
	tabButtons = {}
	tabLabels = {}
	categoryTitle = nil
	itemCount = nil
	emptyLabel = nil
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
	selectedCategory = nil
end

return InventoryController
