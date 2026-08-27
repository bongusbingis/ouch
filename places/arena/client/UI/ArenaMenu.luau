-- Name: ArenaMenu.luau
-- Author: Jack C.
-- Description: React component tree for the in-match arena menu: page routing, the shop, inventory, and settings pages, the toggle button, and its HUD input exclusion region.
-- Created: 2026-08-24

--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Components = UI:WaitForChild("Components")
local AnimatedButton = require(Components:WaitForChild("AnimatedButton"))
local EconomyMenuModals = require(Components:WaitForChild("EconomyMenuModals"))
local InventoryPage = require(Components:WaitForChild("InventoryPage"))
local NotificationModal = require(Components:WaitForChild("NotificationModal"))
local PageTransition = require(Components:WaitForChild("PageTransition"))
local ResponsiveText = require(Components:WaitForChild("ResponsiveText"))
local SettingsPage = require(Components:WaitForChild("SettingsPage"))
local ShopPage = require(Components:WaitForChild("ShopPage"))
local TopBar = require(Components:WaitForChild("TopBar"))
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local EconomyMenuController = require(UI:WaitForChild("Hooks"):WaitForChild("EconomyMenuController"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local useReducedMotion = require(UI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local UIAnalytics = require(UI:WaitForChild("Services"):WaitForChild("UIAnalytics"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local ArenaLoadingClient = require(script.Parent.Parent.Modules.UI.ArenaLoadingClient)
local ArenaMenuClient = require(script.Parent.Parent.Modules.UI.ArenaMenuClient)
local ArenaTeleportClient = require(script.Parent.Parent.Modules.UI.ArenaTeleportClient)
local ModeVoteClient = require(script.Parent.Parent.Modules.UI.ModeVoteClient)

local c = React.createElement

local BACK_ACTION = "CloseArenaMenuLayer"
local BACK_PRIORITY = Enum.ContextActionPriority.High.Value + 2
local SELECTED_IMAGE = "rbxassetid://94748581468730"
local UNSELECTED_IMAGE = "rbxassetid://136021539696619"

local PAGE_POSITIONS = {
	Inventory = {
		onscreen = UDim2.fromScale(0.0211629, 0.14282),
		offscreen = UDim2.fromScale(-1.5, 0.14282),
	},
	Shop = {
		onscreen = UDim2.fromScale(0.5, 0.56),
		offscreen = UDim2.fromScale(-1, 0.56),
	},
	Settings = {
		onscreen = UDim2.fromScale(0.0211629, 0.14282),
		offscreen = UDim2.fromScale(-1.5, 0.14282),
	},
}

local GAMEPAD_IMAGE = ""
do
	local ok, image = pcall(UserInputService.GetImageForKeyCode, UserInputService, Enum.KeyCode.ButtonY)
	if ok and typeof(image) == "string" then
		GAMEPAD_IMAGE = image
	end
end

local function validSelection(selection: Instance?): boolean
	return selection ~= nil
		and selection.Parent ~= nil
		and selection:IsA("GuiObject")
		and selection.Visible
		and selection.Selectable
end

local function menuAvailable(loading, vote, teleportStatus): boolean
	local admission = loading.admission
	local phase = loading.matchPhase
	local returning = teleportStatus ~= nil and teleportStatus.state ~= "Complete"
	return (admission == "Matched" or admission == "Direct")
		and loading.localReady
		and loading.serverReady
		and not vote.open
		and not returning
		and phase == "Active"
end

local function useHudExclusion(buttonRef, enabled: boolean)
	React.useEffect(function()
		local positionConnection: RBXScriptConnection? = nil
		local sizeConnection: RBXScriptConnection? = nil
		local cancelled = false
		local function clear()
			Combat.registerHudExclusion("ArenaMenuButton", nil)
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
				Combat.registerHudExclusion("ArenaMenuButton", {
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
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Position = if not props.Available
			then UDim2.fromScale(-0.16, 0.5)
			else if props.Open then UDim2.fromScale(0.012, 0.95) else UDim2.fromScale(0.012, 0.5),
		config = { mass = 1, tension = 360, friction = 34 },
		immediate = reducedMotion,
	})
	useHudExclusion(buttonRef, props.Available)
	local showGamepadImage = props.InputMethod == "Gamepad" and GAMEPAD_IMAGE ~= ""
	local hint = if props.InputMethod == "Gamepad" then "Y" else if props.InputMethod == "Touch" then "TAP" else "M"

	return c(AnimatedButton, {
		ButtonRef = buttonRef,
		Enabled = props.Available,
		Native = {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = if props.Open then SELECTED_IMAGE else UNSELECTED_IMAGE,
			Position = styles.Position,
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.105, 0.078),
			SliceCenter = Rect.new(224, 202, 770, 474),
			SliceScale = 0.12,
			Visible = props.Available or props.Open,
			ZIndex = 80,
		},
		OnActivated = ArenaMenuClient.toggle,
	}, {
		Bounds = c("UISizeConstraint", {
			MaxSize = Vector2.new(210, 88),
			MinSize = Vector2.new(126, 54),
		}),
		Label = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 32,
			Native = {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.09, 0.54),
				Size = UDim2.fromScale(0.6, 0.58),
				Text = if props.Open then "CLOSE" else "MENU",
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 82,
			},
		}),
		Keycap = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(52, 52, 52),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.91, 0.51),
			Size = UDim2.fromScale(0.27, 0.54),
			ZIndex = 82,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
			Stroke = c("UIStroke", {
				Color = Color3.new(1, 1, 1),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.055,
				Transparency = 0.12,
			}),
			Icon = if showGamepadImage
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = GAMEPAD_IMAGE,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.66, 0.66),
					ZIndex = 83,
				})
				else nil,
			Text = if not showGamepadImage
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MaxTextSize = 24,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/SourceSansPro.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Size = UDim2.fromScale(1, 1),
						Text = hint,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 83,
					},
				})
				else nil,
		}),
	})
end

local function ArenaMenuContent(props)
	local loading = useExternalStore(ArenaLoadingClient.getSnapshot, ArenaLoadingClient.subscribe)
	local vote = useExternalStore(ModeVoteClient.getSnapshot, ModeVoteClient.subscribe)
	local teleportStatus = useExternalStore(ArenaTeleportClient.getSnapshot, ArenaTeleportClient.subscribe)
	local menu = useExternalStore(ArenaMenuClient.getSnapshot, ArenaMenuClient.subscribe)
	local notifications = NotificationContext.useNotification()
	local controller = EconomyMenuController.use({
		ShopClient = props.ShopClient,
		ShopRefreshEnabled = menu.open and menu.page == "Shop",
	})
	local available = menuAvailable(loading, vote, teleportStatus)
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
		ArenaMenuClient.setAvailable(available)
		return function()
			ArenaMenuClient.setAvailable(false)
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
		ArenaMenuClient.setCloseInterceptor(closeTopLayer)
		return function()
			ArenaMenuClient.setCloseInterceptor(nil)
		end
	end, { closeTopLayer })

	React.useEffect(function()
		if available and (notifications.request ~= nil or controller.crateReveal ~= nil) then
			ArenaMenuClient.open()
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
			ArenaMenuClient.close()
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
			Onscreen = positions.onscreen,
			Offscreen = positions.offscreen,
			Render = function(position)
				if pageName == "Inventory" then
					return c(InventoryPage, {
						Data = controller.economyData,
						Position = position,
						SelectedTab = controller.inventoryTab,
						OnTabChanged = controller.setInventoryTab,
						OnEquip = controller.equip,
					})
				elseif pageName == "Shop" then
					return c(ShopPage, {
						Model = controller.shopModel,
						Position = position,
						OnCardActivated = controller.activateShopCard,
						OnRefresh = controller.refreshShop,
					})
				end
				return c(SettingsPage, { Position = position, Place = "Arena" })
			end,
		})
	end

	return c("Frame", {
		ref = rootRef,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Overlay = if present
			then c("Frame", {
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
						OnNavigate = ArenaMenuClient.navigate,
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
					}),
					Economy = c(EconomyMenuModals, {
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
		ArenaMenu = c(ArenaMenuContent, props),
	})
end
