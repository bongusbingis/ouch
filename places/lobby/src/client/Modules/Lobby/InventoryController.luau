--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local InventoryConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Inventory"))
local Economy = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy")
local EconomyStore = require(Economy:WaitForChild("EconomyStore"))
local InventoryModel = require(Economy:WaitForChild("InventoryModel"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local InventoryViewportRenderer = require(script.Parent.InventoryViewportRenderer)

local InventoryController = {}

local started = false
local storeDisconnect: (() -> ())? = nil
local visibilityConnection: RBXScriptConnection? = nil
local tabConnections: { RBXScriptConnection } = {}
local cardConnections: { RBXScriptConnection } = {}
local tabClones: { ImageButton } = {}
local sectionClones: { GuiObject } = {}
local viewportHandles: { InventoryViewportRenderer.Handle } = {}
local cardSelections: { { entry: InventoryModel.Entry, checkmark: GuiObject } } = {}
local currentData: any = nil
local selectedTab = "OUTFITS"
local busySlots: { [string]: boolean } = {}
local renderedOwnershipKey: string? = nil
local renderedTab: string? = nil

local inventoryView: GuiObject
local tabsHolder: GuiObject
local tabTemplate: ImageButton
local categoriesHolder: GuiObject
local categoryHeaderTemplate: GuiObject
local categoryContentTemplate: GuiObject
local spacerTemplate: GuiObject
local notifications: any

local function clearSections()
	for _, connection in cardConnections do
		connection:Disconnect()
	end
	table.clear(cardConnections)
	for _, handle in viewportHandles do
		handle:destroy()
	end
	table.clear(viewportHandles)
	table.clear(cardSelections)
	for _, clone in sectionClones do
		clone:Destroy()
	end
	table.clear(sectionClones)
end

local function notifyFailure(reason: any)
	local messages = {
		rate_limited = "Please wait before changing another item.",
		no_profile = "Your inventory is still loading.",
		not_owned = "That item is not owned.",
		wrong_slot = "That item cannot be equipped in this slot.",
		invalid_slot = "That inventory slot is invalid.",
	}
	notifications:Notify({
		title = "INVENTORY",
		description = messages[reason] or `Unable to equip that item: {tostring(reason or "unknown error")}`,
		buttonText = "OK",
	})
end

local render: () -> ()

local function ownershipKey(): string
	local itemIds = {}
	for itemId, owned in currentData.Cosmetics.Owned do
		local item = Cosmetics.Items[itemId]
		if owned == true and item ~= nil and item.AlwaysAvailable ~= true then
			table.insert(itemIds, itemId)
		end
	end
	table.sort(itemIds)
	return table.concat(itemIds, "\0")
end

local function updateSelections()
	if currentData == nil then
		return
	end
	for _, record in cardSelections do
		record.checkmark.Visible = InventoryModel.isEquipped(record.entry, currentData.Cosmetics.Equipped)
	end
end

local function equip(entry: InventoryModel.Entry)
	if currentData == nil or busySlots[entry.category] then
		return
	end
	local equipped = currentData.Cosmetics.Equipped
	if entry.isDefault and InventoryModel.isEquipped(entry, equipped) then
		return
	end
	local nextItemId = InventoryModel.nextEquip(entry, equipped)
	busySlots[entry.category] = true

	task.spawn(function()
		local callOk, accepted, reason = pcall(Network.call, "EquipCosmetic", entry.category, nextItemId)
		busySlots[entry.category] = nil
		if not started then
			return
		end
		if not callOk then
			notifyFailure("network_error")
		elseif not accepted then
			notifyFailure(reason)
		end
	end)
end

local function cardColor(entry: InventoryModel.Entry): Color3
	local color = entry.definition.PreviewColor or InventoryConfig.RarityColors[entry.rarity]
	assert(color ~= nil, `[InventoryController] unknown rarity {entry.rarity}`)
	return color
end

local function cardName(entry: InventoryModel.Entry): string
	local name = string.gsub(entry.displayName, "^Default%s+", "")
	local suffix = if entry.category == "BallAssets"
		then " Ball"
		elseif entry.category == "HammerAssets" then " Hammer"
		else nil
	if suffix and string.sub(name, -#suffix) == suffix and #name > #suffix then
		name = string.sub(name, 1, #name - #suffix)
	end
	return name
end

local function createCard(content: GuiObject, template: ImageButton, entry: InventoryModel.Entry, layoutOrder: number)
	local card = template:Clone()
	card.Name = entry.id
	card.LayoutOrder = layoutOrder
	card.Visible = true
	card.Active = true
	card.Selectable = true
	local background = card:WaitForChild("Background")
	assert(background:IsA("ImageLabel"), "[InventoryController] ItemCard.Background must be an ImageLabel")
	background.ImageColor3 = cardColor(entry)
	local itemName = card:WaitForChild("ItemName")
	assert(itemName:IsA("TextLabel"), "[InventoryController] ItemCard.ItemName must be a TextLabel")
	itemName.Text = cardName(entry)
	local checkmark = card:WaitForChild("Checkmark")
	assert(checkmark:IsA("GuiObject"), "[InventoryController] ItemCard.Checkmark must be a GuiObject")
	checkmark.Visible = InventoryModel.isEquipped(entry, currentData.Cosmetics.Equipped)
	table.insert(cardSelections, { entry = entry, checkmark = checkmark })
	local viewport = card:WaitForChild("ViewportFrame")
	assert(viewport:IsA("ViewportFrame"), "[InventoryController] ItemCard.ViewportFrame must be a ViewportFrame")
	card.Parent = content
	table.insert(viewportHandles, InventoryViewportRenderer.mount(viewport, entry))
	table.insert(
		cardConnections,
		card.Activated:Connect(function()
			equip(entry)
		end)
	)
end

local function createSection(section: any, entries: { InventoryModel.Entry }, sectionIndex: number)
	local header = categoryHeaderTemplate:Clone()
	header.Name = `CategoryHeader_{section.Id}`
	header.LayoutOrder = sectionIndex * 3
	local headerFrame = header:WaitForChild("Frame")
	local title = header:WaitForChild("Title")
	assert(title:IsA("TextLabel"), "[InventoryController] CategoryHeader.Frame.Title must be a TextLabel")
	title.Text = section.Id
	header.Visible = true
	header.Parent = categoriesHolder
	table.insert(sectionClones, header)

	local content = categoryContentTemplate:Clone()
	content.Name = `CategoryContent_{section.Id}`
	content.LayoutOrder = sectionIndex * 3 + 1
	local itemTemplate = content:WaitForChild("ItemCard")
	local contentLayout = content:WaitForChild("UIListLayout")
	assert(itemTemplate:IsA("ImageButton"), "[InventoryController] CategoryContent.ItemCard must be an ImageButton")
	assert(
		contentLayout:IsA("UIListLayout"),
		"[InventoryController] CategoryContent.UIListLayout must be a UIListLayout"
	)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemTemplate.Visible = false
	content.Visible = true
	content.Parent = categoriesHolder
	table.insert(sectionClones, content)
	for layoutOrder, entry in entries do
		createCard(content, itemTemplate, entry, layoutOrder)
	end

	local spacer = spacerTemplate:Clone()
	spacer.Name = `Spacer_{section.Id}`
	spacer.LayoutOrder = sectionIndex * 3 + 2
	spacer.Visible = true
	spacer.Parent = categoriesHolder
	table.insert(sectionClones, spacer)
end

local function activeTabDefinition(): any
	for _, tab in InventoryConfig.Tabs do
		if tab.Id == selectedTab then
			return tab
		end
	end
	error(`[InventoryController] unknown inventory tab {selectedTab}`)
end

render = function()
	clearSections()
	for _, tab in tabClones do
		local stroke = tab:WaitForChild("SelectedStroke")
		assert(stroke:IsA("UIStroke"), "[InventoryController] TabTemplate.SelectedStroke must be a UIStroke")
		stroke.Enabled = tab.Name == selectedTab
	end
	if not inventoryView.Visible or currentData == nil then
		renderedOwnershipKey = nil
		renderedTab = nil
		return
	end
	renderedOwnershipKey = ownershipKey()
	renderedTab = selectedTab

	local sectionIndex = 0
	for _, section in activeTabDefinition().Sections do
		local entries = InventoryModel.entries(Cosmetics, currentData.Cosmetics.Owned, section.Category)
		if #entries > 0 then
			createSection(section, entries, sectionIndex)
			sectionIndex += 1
		end
	end
end

local function createTabs()
	for layoutOrder, definition in InventoryConfig.Tabs do
		local tab = tabTemplate:Clone()
		tab.Name = definition.Id
		tab.LayoutOrder = layoutOrder
		local label = tab:WaitForChild("TextLabel")
		assert(label:IsA("TextLabel"), "[InventoryController] TabTemplate.TextLabel must be a TextLabel")
		label.Text = definition.Id
		tab.Visible = true
		tab.Active = true
		tab.Selectable = true
		tab.Parent = tabsHolder
		table.insert(tabClones, tab)
		table.insert(
			tabConnections,
			tab.Activated:Connect(function()
				if selectedTab ~= definition.Id then
					selectedTab = definition.Id
					render()
				end
			end)
		)
	end
end

function InventoryController.start(screenGui: ScreenGui, notificationController: any)
	if started then
		return
	end
	started = true
	notifications = notificationController

	local baseClip = screenGui:WaitForChild("BaseClip")
	local views = baseClip:WaitForChild("Views")
	local inventory = views:WaitForChild("Inventory")
	assert(inventory:IsA("GuiObject"), "[InventoryController] Views.Inventory must be a GuiObject")
	inventoryView = inventory

	local tabs = inventory:WaitForChild("Tabs")
	assert(tabs:IsA("GuiObject"), "[InventoryController] Inventory.Tabs must be a GuiObject")
	tabsHolder = tabs
	local tabsLayout = tabs:WaitForChild("UIListLayout")
	assert(tabsLayout:IsA("UIListLayout"), "[InventoryController] Inventory.Tabs.UIListLayout must be a UIListLayout")
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local tab = tabs:WaitForChild("TabTemplate")
	assert(tab:IsA("ImageButton"), "[InventoryController] Inventory.Tabs.TabTemplate must be an ImageButton")
	tabTemplate = tab
	tabTemplate.Visible = false

	local main = inventory:WaitForChild("Main")
	local categories = main:WaitForChild("CategoriesHolder")
	assert(categories:IsA("GuiObject"), "[InventoryController] Inventory.Main.CategoriesHolder must be a GuiObject")
	categoriesHolder = categories
	local categoriesLayout = categories:WaitForChild("UIListLayout")
	assert(
		categoriesLayout:IsA("UIListLayout"),
		"[InventoryController] Inventory.Main.CategoriesHolder.UIListLayout must be a UIListLayout"
	)
	categoriesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local header = categories:WaitForChild("CategoryHeader")
	local content = categories:WaitForChild("CategoryContent")
	local spacer = categories:WaitForChild("Spacer")
	assert(header:IsA("GuiObject"), "[InventoryController] CategoryHeader must be a GuiObject")
	assert(content:IsA("GuiObject"), "[InventoryController] CategoryContent must be a GuiObject")
	assert(spacer:IsA("GuiObject"), "[InventoryController] Spacer must be a GuiObject")
	categoryHeaderTemplate = header
	categoryContentTemplate = content
	spacerTemplate = spacer
	categoryHeaderTemplate.Visible = false
	categoryContentTemplate.Visible = false
	spacerTemplate.Visible = false

	createTabs()
	visibilityConnection = inventoryView:GetPropertyChangedSignal("Visible"):Connect(render)
	EconomyStore.start()
	currentData = EconomyStore.snapshot()
	storeDisconnect = EconomyStore.onChanged(function(data)
		currentData = data
		if inventoryView.Visible and renderedTab == selectedTab and renderedOwnershipKey == ownershipKey() then
			updateSelections()
		else
			render()
		end
	end)
	render()
end

function InventoryController.destroy()
	if not started then
		return
	end
	started = false
	clearSections()
	if storeDisconnect then
		storeDisconnect()
	end
	if visibilityConnection then
		visibilityConnection:Disconnect()
	end
	for _, connection in tabConnections do
		connection:Disconnect()
	end
	for _, tab in tabClones do
		tab:Destroy()
	end
	table.clear(tabConnections)
	table.clear(tabClones)
	table.clear(busySlots)
	storeDisconnect = nil
	visibilityConnection = nil
	currentData = nil
	selectedTab = "OUTFITS"
	renderedOwnershipKey = nil
	renderedTab = nil
end

return InventoryController
