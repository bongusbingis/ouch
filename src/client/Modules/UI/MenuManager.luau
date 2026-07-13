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
local openPositions: { [MenuId]: any } = {}
local scalesById: { [MenuId]: UIScale } = {}
local activeTweens: { [MenuId]: { Tween } } = {}
local animationsEnabled = true
local cachedUIConfig: any = nil

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

local function uiConfig()
	if cachedUIConfig == nil then
		cachedUIConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("UI"))
	end
	return cachedUIConfig
end

local function tweenInfo(spec): TweenInfo
	return TweenInfo.new(spec.Time, spec.EasingStyle, spec.EasingDirection)
end

local function cancelTween(menuId: MenuId)
	local tweens = activeTweens[menuId]
	if tweens then
		for _, tween in tweens do
			tween:Cancel()
		end
		activeTweens[menuId] = nil
	end
end

local function closedPositionFor(menuId: MenuId): any
	local openPosition = openPositions[menuId]
	if openPosition == nil then
		return nil
	end
	return UDim2.new(
		openPosition.X.Scale,
		openPosition.X.Offset,
		openPosition.Y.Scale,
		openPosition.Y.Offset + uiConfig().Menus.ClosedYOffset
	)
end

local function registeredView(root: Instance, definition: MenuDefinition): Instance?
	if animationsEnabled then
		return root:WaitForChild(definition.viewName)
	end
	return root:FindFirstChild(definition.viewName)
end

local function canvasFor(menuId: MenuId, view: GuiObject): CanvasGroup
	assert(view:IsA("CanvasGroup"), `[MenuManager] menu view "{menuId}" must be a CanvasGroup`)
	return view :: CanvasGroup
end

local function scaleFor(menuId: MenuId, view: GuiObject): UIScale
	local cached = scalesById[menuId]
	if cached ~= nil then
		return cached
	end

	local scale = Instance.new("UIScale")
	scale.Name = "MenuScale"
	scale.Parent = view
	scalesById[menuId] = scale
	return scale
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

	local view = registeredView(root, definition)
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
	if view == nil then
		return
	end

	cancelTween(menuId)
	local canvas = if animationsEnabled then canvasFor(menuId, view) else nil
	local scale = if animationsEnabled then scaleFor(menuId, view) else nil

	local function finishClose()
		view.Visible = false
		if definition and definition.onClose then
			definition.onClose(view, reason)
		end
	end

	if not animationsEnabled then
		finishClose()
		return
	end

	local closedPosition = closedPositionFor(menuId)
	if closedPosition == nil then
		finishClose()
		return
	end

	local positionTween = game:GetService("TweenService"):Create(view, tweenInfo(uiConfig().Tweens.Menu.Close), {
		Position = closedPosition,
	})
	local fadeTween = game:GetService("TweenService")
		:Create(canvas :: CanvasGroup, tweenInfo(uiConfig().Tweens.Menu.Close), {
			GroupTransparency = 1,
		})
	local scaleTween = game:GetService("TweenService")
		:Create(scale :: UIScale, tweenInfo(uiConfig().Tweens.Menu.Close), {
			Scale = uiConfig().Menus.ClosedScale,
		})
	activeTweens[menuId] = { positionTween, fadeTween, scaleTween }
	positionTween.Completed:Once(function()
		if activeTweens[menuId] == nil then
			return
		end
		activeTweens[menuId] = nil
		finishClose()
	end)
	positionTween:Play()
	fadeTween:Play()
	scaleTween:Play()
end

local function showMenu(menuId: MenuId): boolean
	local view = viewFor(menuId)
	local definition = definitionFor(menuId)
	if view == nil or definition == nil then
		return false
	end
	cancelTween(menuId)
	local canvas = if animationsEnabled then canvasFor(menuId, view) else nil
	local scale = if animationsEnabled then scaleFor(menuId, view) else nil

	local openPosition = openPositions[menuId] or view.Position
	openPositions[menuId] = openPosition
	if animationsEnabled then
		local closedPosition = closedPositionFor(menuId)
		if closedPosition then
			view.Position = closedPosition
		end
		(canvas :: CanvasGroup).GroupTransparency = 1
		(scale :: UIScale).Scale = uiConfig().Menus.ClosedScale
	end

	view.Visible = true
	if definition.onOpen then
		definition.onOpen(view)
	end

	if animationsEnabled then
		local positionTween = game:GetService("TweenService"):Create(view, tweenInfo(uiConfig().Tweens.Menu.Open), {
			Position = openPosition,
		})
		local fadeTween = game:GetService("TweenService")
			:Create(canvas :: CanvasGroup, tweenInfo(uiConfig().Tweens.Menu.Open), {
				GroupTransparency = 0,
			})
		local scaleTween = game:GetService("TweenService")
			:Create(scale :: UIScale, tweenInfo(uiConfig().Tweens.Menu.Open), {
				Scale = uiConfig().Menus.OpenScale,
			})
		activeTweens[menuId] = { positionTween, fadeTween, scaleTween }
		positionTween.Completed:Once(function()
			if activeTweens[menuId] then
				activeTweens[menuId] = nil
			end
		end)
		positionTween:Play()
		fadeTween:Play()
		scaleTween:Play()
	else
		view.Position = openPosition
	end

	return true
end

local function validateAndHideRegisteredViews()
	viewsById = {}
	for menuId, definition in MenuRegistry do
		local root = viewsRoot
		local view = if root then registeredView(root, definition) else nil
		if view == nil or not view:IsA("GuiObject") then
			warnOnce(
				`startup:{menuId}`,
				`[MenuManager] registered menu "{menuId}" has no GuiObject child "{definition.viewName}" under MainGui.BaseClip.Views`
			)
			continue
		end
		local guiView = view :: GuiObject
		openPositions[menuId] = guiView.Position
		if animationsEnabled then
			local canvas = guiView :: CanvasGroup
			assert(canvas:IsA("CanvasGroup"), `[MenuManager] menu view "{menuId}" must be a CanvasGroup`)
			canvas.GroupTransparency = 1
			scaleFor(menuId, guiView).Scale = uiConfig().Menus.ClosedScale
		end
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
	animationsEnabled = rootOverride == nil
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
	for menuId in activeTweens do
		cancelTween(menuId)
	end
	viewsRoot = nil
	currentMenu = nil
	started = false
	animationsEnabled = true
	escapeConnection = nil
	callbacks = {}
	warned = {}
	viewsById = {}
	openPositions = {}
	scalesById = {}
	cachedUIConfig = nil
end

return MenuManager
