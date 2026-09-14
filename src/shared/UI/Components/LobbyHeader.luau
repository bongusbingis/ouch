-- Composes lobby navigation in core-safe coordinates; only the decorative band reaches screen edges.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local PuffyButton = require(script.Parent.PuffyButton)
local T = require(script.Parent.Parent.Tokens)
local NavGlyph = require(script.Parent.NavGlyph)
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
	local logo = UIConfig.LobbyArtwork.Logo
	local logoSize = TextMetrics.fitAspect(layout.logo.size, logo.Size.X / logo.Size.Y)
	local logoTop = layout.logo.position.Y + layout.logo.size.Y / 2 - logo.OpticalCenterY / logo.Size.Y * logoSize.Y
	local buttons = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, layout.gap),
		}),
	}
	for _, tab in props.Tabs do
		local enabled = tab.Enabled ~= false
		buttons[tab.Id] = c(PuffyButton, {
			ButtonRef = tab.ButtonRef,
			Enabled = enabled,
			Color = if tab.Id == props.CurrentPage then T.Colors.Pink else T.Colors.Cyan,
			LipColor = if tab.Id == props.CurrentPage then T.Colors.PinkLip else T.Colors.CyanLip,
			StrokeColor = T.Colors.Surface,
			SelectionRadius = UDim.new(0, 12),
			OnSelectionGained = tab.OnSelectionGained,
			OnActivated = function()
				props.OnNavigate(tab.Id)
			end,
			Native = {
				BackgroundTransparency = 1,
				Image = "",
				LayoutOrder = tab.LayoutOrder or 0,
				Rotation = if (tab.LayoutOrder or 0) % 2 == 0 then -T.Shape.TiltTab else T.Shape.TiltTab,
				Size = UDim2.fromOffset(layout.buttonWidth, layout.nav.size.Y),
			},
		}, {
			Icon = c(NavGlyph, {
				Id = tab.Id,
				Native = {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 5),
					Size = UDim2.fromOffset(if layout.compact then 26 else 30, if layout.compact then 26 else 30),
					ZIndex = 8,
				},
			}),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 2, 1, -6),
				Size = UDim2.new(1, -4, 0, 24),
				Font = if layout.compact then T.Type.CompactLabel else T.Type.Display,
				Text = tab.Label,
				TextSize = if layout.compact then T.Type.Minimum else T.Type.Body,
				TextColor3 = if enabled then UIConfig.ProgressionStyle.White else UIConfig.ProgressionStyle.Muted,
				ZIndex = 8,
			}, {
				Outline = c("UIStroke", {
					Color = UIConfig.ProgressionStyle.Ink,
					Thickness = UIConfig.Text.OutlineScale,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
		})
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
						Size = UDim2.new(1, 0, 0, insets.coreOffset.Y + safe.position.Y + layout.height),
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
				Position = UDim2.fromOffset(layout.nav.position.X, layout.nav.position.Y),
				Size = UDim2.fromOffset(layout.nav.size.X, layout.nav.size.Y),
				SelectionGroup = true,
			}, buttons),
			Emote = if layout.emote and not wheelBlocked
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
						Position = UDim2.fromOffset(layout.emote.position.X, layout.emote.position.Y),
						Size = UDim2.fromOffset(layout.emote.size.X, layout.emote.size.Y),
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
