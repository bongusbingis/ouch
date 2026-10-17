-- Mobile navigation shares CoreGui's row; the root allows viewport overflow.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local PuffyButton = require(script.Parent.PuffyButton)
local T = require(script.Parent.Parent.Tokens)
local LobbyNavigation = require(script.Parent.LobbyNavigation)
local EmoteWheelController = require(script.Parent.Parent.Services.EmoteWheelController)
local Layout = require(script.Parent.Parent.Models.LobbyHeaderLayout)
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useHeaderInsets = require(script.Parent.Parent.Hooks.useHeaderInsets)

local c = React.createElement

-- Four white candy dots, each with the shared ink outline.
local function emoteDot(order: number)
	return c("Frame", {
		BackgroundColor3 = T.Colors.Surface,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 8,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusPill) }),
		Outline = c("UIStroke", { Color = T.Colors.Ink, Thickness = T.Type.Outline }),
	})
end

return function(props)
	local insets = useHeaderInsets()
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local wheel = EmoteWheelController.useSnapshot()
	local wheelBlocked = EmoteWheelController.useBlocked()
	local touch = wheel.deviceClass == "Touch"
	local layout = Layout.resolve(safe.size, #props.Tabs, touch)
	local mobile = Layout.resolveMobile(safe.size, insets, touch and not wheelBlocked)
	local origin = insets.coreOffset + safe.position
	local emote = if mobile and mobile.emote
		then { position = mobile.emote.position - origin, size = mobile.emote.size }
		else layout.emote
	local logo = UIConfig.LobbyArtwork.Logo
	local logoSize = TextMetrics.fitAspect(layout.logo.size, logo.Size.X / logo.Size.Y)
	local logoTop = layout.logo.position.Y + layout.logo.size.Y / 2 - logo.OpticalCenterY / logo.Size.Y * logoSize.Y
	-- Desktop retains its composition; mobile reuses the free platform row.
	local navLeft, navWidth = layout.nav.position.X, layout.nav.size.X
	local navTop, navHeight = layout.nav.position.Y, layout.nav.size.Y
	if mobile then
		navLeft, navTop = mobile.nav.position.X - origin.X, mobile.nav.position.Y - origin.Y
		navWidth, navHeight = mobile.nav.size.X, mobile.nav.size.Y
	elseif not layout.compact and not layout.stacked then
		local n = T.LobbyNavigation
		local left = layout.logo.position.X + layout.logo.size.X + n.AccessoryGap
		local right = (layout.emote or layout.party).position.X - n.AccessoryGap
		navWidth = math.max(navWidth, math.min(safe.size.X * n.WidthFraction, n.MaxWidth, right - left))
		navLeft = math.clamp((safe.size.X - navWidth) / 2, left, math.max(left, right - navWidth))
		navHeight = n.Height
		navTop = (layout.height - navHeight) / 2
	end
	local dot = if emote then math.round(math.min(emote.size.X, emote.size.Y) * 0.2) else 0
	local dotGap = math.round(dot * 0.9)
	local dotCluster = dot * 2 + dotGap
	local decorationTarget = props.DecorationTarget
	if decorationTarget == nil then
		local player = Players.LocalPlayer
		decorationTarget = if player then player:FindFirstChildOfClass("PlayerGui") else false
	end
	local decoration = if decorationTarget
		then ReactRoblox.createPortal(
			c(React.Fragment, nil, {
				LobbyHeaderDecoration = c("ScreenGui", {
					Enabled = props.Visible ~= false,
					ScreenInsets = Enum.ScreenInsets.None,
					ClipToDeviceSafeArea = false,
					SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
					ResetOnSpawn = false,
					DisplayOrder = -1,
					ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				}, {
					Band = c("Frame", {
						Active = false,
						Selectable = false,
						BackgroundColor3 = T.Colors.Ink,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, if mobile then mobile.bandHeight else origin.Y + layout.height),
					}, {
						Pattern = c("ImageLabel", {
							BackgroundTransparency = 1,
							Image = T.Texture.Swirl,
							ImageColor3 = T.Colors.Surface,
							ImageTransparency = 0.94,
							ScaleType = Enum.ScaleType.Tile,
							TileSize = UDim2.fromOffset(240, 240),
							Size = UDim2.fromScale(1, 1),
						}),
						Scallop = c("Frame", {
							BackgroundColor3 = T.Colors.Ink,
							BorderSizePixel = 0,
							Position = UDim2.new(0, 0, 1, -12),
							Size = UDim2.new(1, 0, 0, 24),
						}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusPanel) }) }),
					}),
				}),
			}),
			decorationTarget
		)
		else nil
	return c(React.Fragment, nil, {
		Decoration = decoration,
		Controls = c("Frame", {
			Visible = props.Visible ~= false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(safe.position.X, safe.position.Y),
			Size = UDim2.fromOffset(safe.size.X, layout.height),
		}, {
			Logo = c("ImageLabel", {
				Visible = mobile == nil,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(layout.logo.position.X, logoTop),
				Size = UDim2.fromOffset(logoSize.X, logoSize.Y),
				Image = UIConfig.LobbyArtwork.Logo.Image,
				ImageRectOffset = UIConfig.LobbyArtwork.Logo.Offset,
				ImageRectSize = UIConfig.LobbyArtwork.Logo.Size,
				ScaleType = Enum.ScaleType.Fit,
			}),
			PageTabs = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(navLeft, navTop),
				Size = UDim2.fromOffset(navWidth, navHeight),
				SelectionGroup = true,
			}, {
				Navigation = c(LobbyNavigation, {
					Tabs = props.Tabs,
					CurrentPage = props.CurrentPage,
					OnNavigate = props.OnNavigate,
					Width = navWidth,
					Compact = mobile ~= nil or layout.compact,
					IconOnly = mobile ~= nil and mobile.iconOnly,
					CycleEnabled = props.CycleEnabled == true and props.Visible ~= false,
				}),
			}),
			Emote = if emote and not wheelBlocked
				then c(PuffyButton, {
					Color = T.Colors.Cyan,
					LipColor = T.Colors.CyanLip,
					StrokeColor = T.LobbyNavigation.Rim,
					Shadow = false,
					OnActivated = function()
						EmoteWheelController.openTouch()
					end,
					Native = {
						Position = UDim2.fromOffset(emote.position.X, emote.position.Y),
						Size = UDim2.fromOffset(emote.size.X, emote.size.Y),
					},
				}, {
					-- A centred 2x2 cluster, sized from the control so it holds at every scale.
					Dots = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.new(0.5, 0, 0.5, -T.Shape.LipHeight / 2),
						Size = UDim2.fromOffset(dotCluster, dotCluster),
						ZIndex = 8,
					}, {
						Grid = c("UIGridLayout", {
							CellPadding = UDim2.fromOffset(dotGap, dotGap),
							CellSize = UDim2.fromOffset(dot, dot),
							FillDirectionMaxCells = 2,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Dot1 = emoteDot(1),
						Dot2 = emoteDot(2),
						Dot3 = emoteDot(3),
						Dot4 = emoteDot(4),
					}),
				})
				else nil,
		}),
	})
end
