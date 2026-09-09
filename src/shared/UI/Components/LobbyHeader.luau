-- Composes lobby navigation in core-safe coordinates; only the decorative band reaches screen edges.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ButtonSurface = require(script.Parent.ButtonSurface)
local Layout = require(script.Parent.Parent.Models.LobbyHeaderLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useHeaderInsets = require(script.Parent.Parent.Hooks.useHeaderInsets)

local c = React.createElement

return function(props)
	local insets = useHeaderInsets()
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local layout = Layout.resolve(safe.size, #props.Tabs)
	local buttons = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, layout.gap),
		}),
	}
	for _, tab in props.Tabs do
		local enabled = tab.Enabled ~= false
		buttons[tab.Id] = c(AnimatedButton, {
			ButtonRef = tab.ButtonRef,
			Enabled = enabled,
			Visual = c(ButtonSurface, {
				Enabled = enabled,
				Color = if tab.Id == props.CurrentPage
					then UIConfig.ProgressionStyle.Pink
					else UIConfig.ProgressionStyle.Cyan,
				Radius = UDim.new(0, 12),
			}),
			SelectionRadius = UDim.new(0, 12),
			OnSelectionGained = tab.OnSelectionGained,
			OnActivated = function()
				props.OnNavigate(tab.Id)
			end,
			Native = {
				BackgroundTransparency = 1,
				Image = "",
				LayoutOrder = tab.LayoutOrder or 0,
				Size = UDim2.fromOffset(layout.buttonWidth, layout.nav.size.Y),
			},
		}, {
			Icon = c("ImageLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 5),
				Size = UDim2.fromOffset(if layout.compact then 28 else 34, if layout.compact then 28 else 34),
				Image = tab.Icon,
				ScaleType = Enum.ScaleType.Fit,
				ImageTransparency = if enabled then 0 else 0.25,
				ZIndex = 2,
			}),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 2, 1, -4),
				Size = UDim2.new(1, -4, 0, 18),
				Font = UIConfig.Text.BodyFont,
				Text = tab.Label,
				TextSize = if layout.buttonWidth < 74 then 12 else if layout.compact then 13 else 15,
				TextColor3 = if enabled then UIConfig.ProgressionStyle.White else UIConfig.ProgressionStyle.Muted,
				ZIndex = 2,
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
						BackgroundColor3 = UIConfig.ProgressionStyle.Ink,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, insets.coreOffset.Y + safe.position.Y + layout.height),
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
				Position = UDim2.fromOffset(layout.logo.position.X, layout.logo.position.Y),
				Size = UDim2.fromOffset(layout.logo.size.X, layout.logo.size.Y),
				Image = "rbxassetid://78333957912633",
				ScaleType = Enum.ScaleType.Fit,
			}),
			PageTabs = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(layout.nav.position.X, layout.nav.position.Y),
				Size = UDim2.fromOffset(layout.nav.size.X, layout.nav.size.Y),
				SelectionGroup = true,
			}, buttons),
		}),
	})
end
