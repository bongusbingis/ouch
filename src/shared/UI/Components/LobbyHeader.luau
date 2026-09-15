-- Mobile navigation shares CoreGui's row; the root allows viewport overflow.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local T = require(script.Parent.Parent.Tokens)
local LobbyNavigation = require(script.Parent.LobbyNavigation)
local EmoteWheelController = require(script.Parent.Parent.Services.EmoteWheelController)
local ButtonSurface = require(script.Parent.ButtonSurface)
local Layout = require(script.Parent.Parent.Models.LobbyHeaderLayout)
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useHeaderInsets = require(script.Parent.Parent.Hooks.useHeaderInsets)

local c = React.createElement

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
	return c(React.Fragment, nil, {
		Decoration = ReactRoblox.createPortal(
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
			Players.LocalPlayer:WaitForChild("PlayerGui")
		),
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
				}),
			}),
			Emote = if emote and not wheelBlocked
				then c(AnimatedButton, {
					Enabled = true,
					Visual = c(ButtonSurface, {
						Enabled = true,
						Color = UIConfig.ProgressionStyle.Cyan,
						Radius = UDim.new(0, 12),
					}),
					SelectionRadius = UDim.new(0, 12),
					OnActivated = function()
						EmoteWheelController.openTouch()
					end,
					Native = {
						BackgroundTransparency = 1,
						Image = "",
						Position = UDim2.fromOffset(emote.position.X, emote.position.Y),
						Size = UDim2.fromOffset(emote.size.X, emote.size.Y),
					},
				}, {
					Dots = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
						TopLeft = c("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = UIConfig.ProgressionStyle.White,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.36, 0.36),
							Size = UDim2.fromOffset(9, 9),
							ZIndex = 3,
						}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
						TopRight = c("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = UIConfig.ProgressionStyle.White,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.64, 0.36),
							Size = UDim2.fromOffset(9, 9),
							ZIndex = 3,
						}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
						BottomLeft = c("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = UIConfig.ProgressionStyle.White,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.36, 0.64),
							Size = UDim2.fromOffset(9, 9),
							ZIndex = 3,
						}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
						BottomRight = c("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = UIConfig.ProgressionStyle.White,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.64, 0.64),
							Size = UDim2.fromOffset(9, 9),
							ZIndex = 3,
						}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
					}),
				})
				else nil,
		}),
	})
end
