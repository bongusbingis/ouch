-- Description: React component tree for the in-combat overlay menu shared by both places: page routing, the shop, inventory, and settings pages, the toggle button, and its HUD input exclusion region. Availability is decided by the caller and passed in, so the arena and the lobby test session drive the same menu from their own gating.

--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Components = UI:WaitForChild("Components")
local PuffyButton = require(Components:WaitForChild("PuffyButton"))
local T = require(UI.Tokens)
local useArenaHUDLayout = require(UI.Hooks.useArenaHUDLayout)
local EconomyMenuModals = require(Components:WaitForChild("EconomyMenuModals"))
local InventoryPage = require(Components:WaitForChild("InventoryPage"))
local NotificationModal = require(Components:WaitForChild("NotificationModal"))
local PageTransition = require(Components:WaitForChild("PageTransition"))
local SettingsPage = require(Components:WaitForChild("SettingsPage"))
local ShopPage = require(Components:WaitForChild("ShopPage"))
local TopBar = require(Components:WaitForChild("TopBar"))
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local EconomyMenuController = require(UI:WaitForChild("Hooks"):WaitForChild("EconomyMenuController"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local useReducedMotion = require(UI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local UIAnalytics = require(UI:WaitForChild("Services"):WaitForChild("UIAnalytics"))
local CombatMenuClient = require(UI:WaitForChild("Services"):WaitForChild("CombatMenuClient"))
local CosmeticPreviewClient = require(UI.Services.CosmeticPreviewClient)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local useSafeArea = require(UI.Hooks.useSafeArea)
local ResponsiveLayout = require(UI.Models.ResponsiveLayout)
local modalSurface = require(script.Parent.ModalSurface)

local c = React.createElement

local BACK_ACTION = "CloseCombatMenuLayer"
local BACK_PRIORITY = Enum.ContextActionPriority.High.Value + 2

local PAGE_POSITIONS = {
	Inventory = {
		onscreen = UIConfig.Layout.PagePosition,
		offscreen = UIConfig.Layout.PageOffscreen,
	},
	Shop = {
		onscreen = UIConfig.Layout.PagePosition,
		offscreen = UIConfig.Layout.PageOffscreen,
	},
	Settings = {
		onscreen = UIConfig.Layout.PagePosition,
		offscreen = UIConfig.Layout.PageOffscreen,
	},
}

local function validSelection(selection: Instance?): boolean
	return selection ~= nil
		and selection.Parent ~= nil
		and selection:IsA("GuiObject")
		and selection.Visible
		and selection.Selectable
end

local function useHudExclusion(buttonRef, enabled: boolean)
	React.useEffect(function()
		local positionConnection: RBXScriptConnection? = nil
		local sizeConnection: RBXScriptConnection? = nil
		local cancelled = false
		local function clear()
			Combat.registerHudExclusion("CombatMenuButton", nil)
		end
		local function attach()
			if cancelled then
				return
			end
			local button = buttonRef.current
			if not enabled or button == nil then
				clear()
				return
			end
			local function register()
				local position = button.AbsolutePosition
				local size = button.AbsoluteSize
				Combat.registerHudExclusion("CombatMenuButton", {
					minX = position.X,
					minY = position.Y,
					maxX = position.X + size.X,
					maxY = position.Y + size.Y,
				})
			end
			register()
			positionConnection = button:GetPropertyChangedSignal("AbsolutePosition"):Connect(register)
			sizeConnection = button:GetPropertyChangedSignal("AbsoluteSize"):Connect(register)
		end
		task.defer(attach)
		return function()
			cancelled = true
			if positionConnection then
				positionConnection:Disconnect()
			end
			if sizeConnection then
				sizeConnection:Disconnect()
			end
			clear()
		end
	end, { buttonRef, enabled })
end

local function MenuToggle(props)
	local buttonRef = React.useRef(nil)
	local geometry, origin = useArenaHUDLayout(Enum.ScreenInsets.CoreUISafeInsets)
	useHudExclusion(buttonRef, props.Available)
	local position = geometry.menu.position - origin
	return c(PuffyButton, {
		ButtonRef = buttonRef,
		Enabled = props.Available,
		Text = if props.Open then "CLOSE" else "MENU",
		TextSize = 17,
		TextColor = T.Colors.Ink,
		Color = if props.Open then T.Colors.Yellow else T.Colors.SurfaceWarm,
		LipColor = if props.Open then T.Colors.YellowLip else T.Colors.WellLine,
		Shadow = false,
		Native = {
			Position = if props.Open then UDim2.new(1, -88, 1, -54) else UDim2.fromOffset(position.X, position.Y),
			Size = UDim2.fromOffset(geometry.menu.size.X, geometry.menu.size.Y),
			Visible = props.Available or props.Open,
			ZIndex = 80,
		},
		OnActivated = CombatMenuClient.toggle,
	})
end

local function CombatMenuContent(props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local shortPages = not ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
		and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local available = props.Available == true
	local menu = useExternalStore(CombatMenuClient.getSnapshot, CombatMenuClient.subscribe)
	local preview = useExternalStore(CosmeticPreviewClient.getSnapshot, CosmeticPreviewClient.subscribe)
	React.useEffect(function()
		if not menu.open then
			CosmeticPreviewClient.close(nil, "menu_closed")
		end
	end, { menu.open })
	local notifications = NotificationContext.useNotification()
	local viewInventory = React.useCallback(function()
		CombatMenuClient.navigate("Inventory")
	end, {})
	local controller = EconomyMenuController.use({
		ShopClient = props.ShopClient,
		ShopRefreshEnabled = menu.open and menu.page == "Shop",
		OnViewInventory = viewInventory,
	})
	local rootRef = React.useRef(nil)
	local inventoryTabRef = React.useRef(nil)
	local shopTabRef = React.useRef(nil)
	local settingsTabRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local focusRevision = React.useRef(0)
	local reducedMotion = useReducedMotion()
	local present, setPresent = React.useState(menu.open)
	local transitionRevision = React.useRef(0)
	local styles, api = ReactSpring.useSpring(function()
		return {
			BackdropTransparency = if menu.open then 0.78 else 1,
			NavigationPosition = if menu.open then UDim2.fromScale(0, 0) else UDim2.fromScale(0, -0.14),
		}
	end)

	React.useEffect(function()
		CombatMenuClient.setAvailable(available)
		return function()
			CombatMenuClient.setAvailable(false)
		end
	end, { available })
	React.useEffect(function()
		if not available then
			controller.CloseAll()
		end
	end, { available, controller.CloseAll })

	local closeTopLayer = React.useCallback(function(): boolean
		return controller.CloseTopLayer()
	end, { controller.CloseTopLayer })

	React.useEffect(function()
		CombatMenuClient.setCloseInterceptor(closeTopLayer)
		return function()
			CombatMenuClient.setCloseInterceptor(nil)
		end
	end, { closeTopLayer })

	React.useEffect(function()
		if available and (notifications.request ~= nil or controller.crateReveal ~= nil) then
			CombatMenuClient.open()
		end
	end, { available, notifications.request, controller.crateReveal })

	React.useEffect(function()
		if not menu.open then
			return
		end
		ContextActionService:BindActionAtPriority(BACK_ACTION, function(_name, inputState)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Sink
			end
			if closeTopLayer() then
				return Enum.ContextActionResult.Sink
			end
			CombatMenuClient.close()
			return Enum.ContextActionResult.Sink
		end, false, BACK_PRIORITY, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
		return function()
			ContextActionService:UnbindAction(BACK_ACTION)
		end
	end, { menu.open, closeTopLayer })

	React.useEffect(function()
		transitionRevision.current += 1
		local revision = transitionRevision.current
		if menu.open then
			setPresent(true)
			api.start({
				BackdropTransparency = 0.78,
				NavigationPosition = UDim2.fromScale(0, 0),
				config = { mass = 1, tension = 320, friction = 34 },
				immediate = reducedMotion,
			})
		else
			api.start({
				BackdropTransparency = 1,
				NavigationPosition = UDim2.fromScale(0, -0.14),
				config = { mass = 1, tension = 320, friction = 34 },
				immediate = reducedMotion,
			}):andThen(function()
				if transitionRevision.current == revision then
					setPresent(false)
				end
			end)
		end
		return function()
			transitionRevision.current += 1
		end
	end, { menu.open, reducedMotion })

	React.useEffect(function()
		return function()
			api.stop()
			ContextActionService:UnbindAction(BACK_ACTION)
		end
	end, {})

	React.useEffect(function()
		focusRevision.current += 1
		local revision = focusRevision.current
		local root = rootRef.current
		if menu.open then
			if previousSelection.current == nil then
				previousSelection.current = GuiService.SelectedObject
			end
			if menu.inputMethod == "Gamepad" then
				task.defer(function()
					if focusRevision.current ~= revision then
						return
					end
					local ref = if menu.page == "Shop"
						then shopTabRef
						elseif menu.page == "Settings" then settingsTabRef
						else inventoryTabRef
					local button = ref.current
					if validSelection(button) then
						GuiService.SelectedObject = button
					end
				end)
			elseif
				root ~= nil
				and GuiService.SelectedObject ~= nil
				and GuiService.SelectedObject:IsDescendantOf(root)
			then
				GuiService.SelectedObject = nil
			end
		else
			local previous = previousSelection.current
			previousSelection.current = nil
			if validSelection(previous) then
				GuiService.SelectedObject = previous
			elseif
				root ~= nil
				and GuiService.SelectedObject ~= nil
				and GuiService.SelectedObject:IsDescendantOf(root)
			then
				GuiService.SelectedObject = nil
			end
		end
		return function()
			focusRevision.current += 1
		end
	end, { menu.open, menu.page, menu.inputMethod })

	React.useEffect(function()
		if menu.open then
			UIAnalytics.menuOpened(menu.page)
		end
	end, { menu.open, menu.page })

	local tabs = {
		{
			Id = "Shop",
			Label = "SHOP",
			Icon = "rbxassetid://18136118615",
			LayoutOrder = 1,
			IconPosition = UDim2.fromScale(0.47, 0.5),
			IconSize = UDim2.fromScale(0.486154, 0.628),
			LabelPosition = UDim2.fromScale(0.465819, 0),
			ButtonRef = shopTabRef,
		},
		{
			Id = "Inventory",
			Label = "BACKPACK",
			Icon = "rbxassetid://18245740340",
			LayoutOrder = 2,
			IconPosition = UDim2.fromScale(0.493847, 0.484),
			IconSize = UDim2.fromScale(0.496643, 0.66),
			LabelPosition = UDim2.fromScale(0.5, 0),
			ButtonRef = inventoryTabRef,
		},
		{
			Id = "Settings",
			Label = "SETTINGS",
			Icon = "rbxassetid://2161586632",
			LayoutOrder = 3,
			IconPosition = UDim2.fromScale(0.495312, 0.481),
			IconSize = UDim2.fromScale(0.542942, 0.75),
			LabelPosition = UDim2.fromScale(0.499999, 0),
			ButtonRef = settingsTabRef,
		},
	}
	local views = {}
	for pageName, positions in PAGE_POSITIONS do
		views[pageName] = c(PageTransition, {
			Active = menu.open and menu.page == pageName,
			Onscreen = if shortPages then UIConfig.Layout.ShortPagePosition else positions.onscreen,
			Offscreen = if shortPages then UIConfig.Layout.ShortPageOffscreen else positions.offscreen,
			Render = function(position)
				if pageName == "Inventory" then
					return c(InventoryPage, {
						Data = controller.economyData,
						Position = position,
						SelectedTab = controller.inventoryTab,
						OnTabChanged = controller.setInventoryTab,
						OnEquip = controller.equip,
						OnInspect = controller.inspectInventory,
						OnLockedSlot = function()
							CombatMenuClient.navigate("Shop")
						end,
					})
				elseif pageName == "Shop" then
					return c(ShopPage, {
						Model = controller.shopModel,
						Position = position,
						OnCardActivated = controller.activateShopCard,
						OnRefresh = controller.refreshShop,
					})
				end
				return c(SettingsPage, { Position = position, Place = props.Place })
			end,
		})
	end

	return c("Frame", {
		ref = rootRef,
		Visible = not preview.active,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Overlay = if present
			then modalSurface({
				ClassName = "Frame",
				Active = true,
				BackgroundColor3 = Color3.fromRGB(17, 24, 28),
				BackgroundTransparency = styles.BackdropTransparency,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				SelectionGroup = true,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				Views = c("Frame", {
					ClipsDescendants = true,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 3,
				}, views),
				Navigation = c("Frame", {
					BackgroundTransparency = 1,
					Position = styles.NavigationPosition,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 20,
				}, {
					TopBar = c(TopBar, {
						CurrentPage = menu.page,
						OnNavigate = CombatMenuClient.navigate,
						Tabs = tabs,
					}),
				}),
				Modals = c("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 100,
				}, {
					Notification = c(NotificationModal, {
						Request = notifications.request,
						OnChoose = notifications.close,
						FocusEnabled = not preview.active,
					}),
					Economy = c(EconomyMenuModals, {
						FocusEnabled = notifications.request == nil,
						Controller = controller,
					}),
				}),
			})
			else nil,
		Toggle = c(MenuToggle, {
			Available = menu.available,
			Open = menu.open,
			InputMethod = menu.inputMethod,
		}),
	})
end

return function(props)
	return c(NotificationContext.Provider, nil, {
		CombatMenu = c(CombatMenuContent, props),
	})
end
