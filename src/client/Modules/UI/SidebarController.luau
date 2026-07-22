--!strict

local MenuManager = require(script.Parent.MenuManager)
local MenuRegistry = require(script.Parent.MenuRegistry)
local MenuTypes = require(script.Parent.MenuTypes)
local ButtonElement = require(script.Parent.Elements.ButtonElement)
local ElementFactory = require(script.Parent.Elements.ElementFactory)
local ElementTypes = require(script.Parent.Elements.ElementTypes)
local QuestsController = require(script.Parent.QuestsController)

type MenuId = MenuTypes.MenuId
type MenuDefinition = MenuTypes.MenuDefinition
type MenuButtonHandle = ElementTypes.MenuButtonHandle

type ButtonElementLike = {
	mount: (parent: Instance, props: ElementTypes.ButtonProps, options: any?) -> MenuButtonHandle,
}

type StartOptions = {
	buttonElement: ButtonElementLike?,
	buttonOptions: any?,
}

local SidebarController = {}

local started = false
local handles: { [MenuId]: MenuButtonHandle } = {}
local menuDisconnect: (() -> ())? = nil
local questDisconnect: (() -> ())? = nil
local questBadgeHandle: ElementTypes.ElementHandle? = nil

local function resolveSidebar(): Frame
	local players = game:GetService("Players")
	local player = players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("Hud")
	local sidebar = hud:WaitForChild("Side")
	assert(sidebar:IsA("Frame"), "[SidebarController] Hud.Sidebar must be a Frame")
	return sidebar
end

local function orderedMenus(): { { id: MenuId, definition: MenuDefinition } }
	local entries = {}
	for menuId, definition in MenuRegistry do
		if definition.showInSidebar ~= false then
			table.insert(entries, {
				id = menuId,
				definition = definition,
			})
		end
	end

	table.sort(entries, function(left, right)
		local leftOrder = left.definition.sidebarOrder or 0
		local rightOrder = right.definition.sidebarOrder or 0
		if leftOrder == rightOrder then
			return left.id < right.id
		end
		return leftOrder < rightOrder
	end)

	return entries
end

local function syncSelected(openMenu: MenuId?)
	for menuId, handle in handles do
		handle:setSelected(menuId == openMenu)
	end
end

function SidebarController.start(sidebarOverride: Instance?, options: StartOptions?)
	if started then
		return
	end

	started = true
	local sidebar = sidebarOverride or resolveSidebar()
	assert(sidebar:IsA("GuiObject"), "[SidebarController] sidebar root must be a GuiObject")

	local element = if options and options.buttonElement then options.buttonElement else ButtonElement
	for _, entry in orderedMenus() do
		local menuId = entry.id
		local definition = entry.definition
		handles[menuId] = element.mount(sidebar, {
			text = definition.label or definition.id,
			name = `{definition.id}Button`,
			color = definition.color,
			layoutOrder = definition.sidebarOrder,
			selected = MenuManager.isOpen(menuId),
			activated = function()
				MenuManager.open(menuId)
			end,
		}, if options then options.buttonOptions else nil)
	end

	local questsButton = handles.Quests
	if questsButton and not (options and options.buttonElement) then
		local template = ElementFactory.resolveTemplate("NotificationBadge", "ImageLabel") :: ImageLabel
		local badge, badgeHandle = ElementFactory.cloneMount(template, questsButton.instance)
		assert(badge:IsA("ImageLabel"), "[SidebarController] NotificationBadge must be an ImageLabel")
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.86, 0.16)
		badge.Size = UDim2.fromScale(0.3, 0.3)
		badge.ZIndex = questsButton.instance.ZIndex + 2
		questBadgeHandle = badgeHandle
		questDisconnect = QuestsController.onClaimableChanged(function(claimable)
			badge.Visible = claimable
		end)
	end

	menuDisconnect = MenuManager.onChanged(function(newMenu)
		syncSelected(newMenu)
	end)
	syncSelected(MenuManager.getOpenMenu())
end

function SidebarController._resetForTest()
	if menuDisconnect then
		menuDisconnect()
	end
	if questDisconnect then
		questDisconnect()
	end
	if questBadgeHandle then
		questBadgeHandle:destroy()
	end
	for _, handle in handles do
		handle:destroy()
	end
	started = false
	handles = {}
	menuDisconnect = nil
	questDisconnect = nil
	questBadgeHandle = nil
end

return SidebarController
