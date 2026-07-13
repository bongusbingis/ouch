--!strict

local MenuRegistry = require(script.Parent.MenuRegistry)
local MenuTypes = require(script.Parent.MenuTypes)

type MenuId = MenuTypes.MenuId
type CloseReason = MenuTypes.CloseReason
type MenuDefinition = MenuTypes.MenuDefinition
type ChangedCallback = MenuTypes.ChangedCallback
type Disconnect = MenuTypes.Disconnect

local MenuManager = {}

local viewsRoot: Instance? = nil
local currentMenu: MenuId? = nil
local started = false
local escapeConnection: RBXScriptConnection? = nil
local callbacks: { ChangedCallback } = {}
local warned: { [string]: boolean } = {}
local viewsById: { [MenuId]: GuiObject } = {}

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function resolveViewsRoot(): Instance
	local players = game:GetService("Players")
	local player = players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("MainGui")
	local baseClip = mainGui:WaitForChild("BaseClip")
	return baseClip:WaitForChild("Views")
end

local function notify(newMenu: MenuId?, oldMenu: MenuId?, reason: CloseReason?)
	for _, callback in callbacks do
		local ok, err = pcall(callback, newMenu, oldMenu, reason)
		if not ok then
			warn(`[MenuManager] onChanged callback failed: {err}`)
		end
	end
end

local function isRegistered(menuId: string): boolean
	return (MenuRegistry :: { [string]: MenuDefinition })[menuId] ~= nil
end

local function definitionFor(menuId: MenuId): MenuDefinition?
	return MenuRegistry[menuId]
end

local function viewFor(menuId: MenuId): GuiObject?
	local cached = viewsById[menuId]
	if cached ~= nil then
		return cached
	end

	local root = viewsRoot
	local definition = definitionFor(menuId)
	if root == nil or definition == nil then
		return nil
	end

	local view = root:FindFirstChild(definition.viewName)
	if view == nil or not view:IsA("GuiObject") then
		warnOnce(`missing:{menuId}`, `[MenuManager] missing GuiObject view "{definition.viewName}" for menu "{menuId}"`)
		return nil
	end

	viewsById[menuId] = view :: GuiObject
	return view :: GuiObject
end

local function hideMenu(menuId: MenuId, reason: CloseReason)
	local view = viewFor(menuId)
	local definition = definitionFor(menuId)
	if view then
		view.Visible = false
		if definition and definition.onClose then
			definition.onClose(view, reason)
		end
	end
end

local function showMenu(menuId: MenuId): boolean
	local view = viewFor(menuId)
	local definition = definitionFor(menuId)
	if view == nil or definition == nil then
		return false
	end
	view.Visible = true
	if definition.onOpen then
		definition.onOpen(view)
	end
	return true
end

local function validateAndHideRegisteredViews()
	viewsById = {}
	for menuId, definition in MenuRegistry do
		local root = viewsRoot
		local view = if root then root:FindFirstChild(definition.viewName) else nil
		if view == nil or not view:IsA("GuiObject") then
			warnOnce(
				`startup:{menuId}`,
				`[MenuManager] registered menu "{menuId}" has no GuiObject child "{definition.viewName}" under MainGui.BaseClip.Views`
			)
			continue
		end
		local guiView = view :: GuiObject
		guiView.Visible = false
		viewsById[menuId] = guiView
	end
end

local function bindEscapeToClose()
	if escapeConnection ~= nil then
		return
	end

	local userInputService = game:GetService("UserInputService")
	escapeConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			MenuManager.close("Escape")
		end
	end)
end

function MenuManager.start(rootOverride: Instance?)
	if started then
		return
	end

	started = true
	viewsRoot = rootOverride or resolveViewsRoot()
	currentMenu = nil
	validateAndHideRegisteredViews()

	if rootOverride == nil then
		bindEscapeToClose()
	end
end

function MenuManager.open(menuId: MenuId): boolean
	if not started then
		MenuManager.start()
	end

	if not isRegistered(menuId) then
		warnOnce(`unknown:{menuId}`, `[MenuManager] unknown menu "{menuId}"`)
		return false
	end

	local oldMenu = currentMenu
	if oldMenu == menuId then
		hideMenu(menuId, "Toggle")
		currentMenu = nil
		notify(nil, oldMenu, "Toggle")
		return false
	end

	local newView = viewFor(menuId)
	if newView == nil then
		return false
	end

	if oldMenu then
		hideMenu(oldMenu, "Switch")
	end
	if not showMenu(menuId) then
		return false
	end

	currentMenu = menuId
	notify(menuId, oldMenu, if oldMenu then "Switch" else nil)
	return true
end

function MenuManager.close(reason: CloseReason?): boolean
	local oldMenu = currentMenu
	if oldMenu == nil then
		return false
	end

	local closeReason = reason or "Api"
	hideMenu(oldMenu, closeReason)
	currentMenu = nil
	notify(nil, oldMenu, closeReason)
	return true
end

function MenuManager.toggle(menuId: MenuId): boolean
	return MenuManager.open(menuId)
end

function MenuManager.isOpen(menuId: MenuId?): boolean
	if menuId == nil then
		return currentMenu ~= nil
	end
	return currentMenu == menuId
end

function MenuManager.getOpenMenu(): MenuId?
	return currentMenu
end

function MenuManager.onChanged(callback: ChangedCallback): Disconnect
	table.insert(callbacks, callback)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

function MenuManager._resetForTest()
	if escapeConnection then
		escapeConnection:Disconnect()
	end
	viewsRoot = nil
	currentMenu = nil
	started = false
	escapeConnection = nil
	callbacks = {}
	warned = {}
	viewsById = {}
end

return MenuManager
