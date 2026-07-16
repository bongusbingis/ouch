--!strict

local MenuManager = require(script.Parent.MenuManager)
local MenuRegistry = require(script.Parent.MenuRegistry)
local MenuTypes = require(script.Parent.MenuTypes)
local ButtonElement = require(script.Parent.Elements.ButtonElement)
local ElementTypes = require(script.Parent.Elements.ElementTypes)

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

	menuDisconnect = MenuManager.onChanged(function(newMenu)
		syncSelected(newMenu)
	end)
	syncSelected(MenuManager.getOpenMenu())
end

function SidebarController._resetForTest()
	if menuDisconnect then
		menuDisconnect()
	end
	for _, handle in handles do
		handle:destroy()
	end
	started = false
	handles = {}
	menuDisconnect = nil
end

return SidebarController
