-- Name: TopBar.luau
-- Author: Jack C.
-- Description: The persistent top bar showing balances and the menu navigation actions.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement
local SELECTED = "rbxassetid://94748581468730"
local UNSELECTED = "rbxassetid://136021539696619"

export type TabDefinition = {
	Id: string,
	Label: string,
	Icon: string,
	LayoutOrder: number?,
	IconPosition: UDim2?,
	IconSize: UDim2?,
	LabelPosition: UDim2?,
	LabelSize: UDim2?,
	ButtonPosition: UDim2?,
	ButtonSize: UDim2?,
	ZIndex: number?,
	Enabled: boolean?,
	ButtonRef: any?,
	OnSelectionGained: ((GuiButton) -> ())?,
}

local DEFINITIONS: { TabDefinition } = {
	{
		Id = "Settings",
		Label = "SETTINGS",
		Icon = "rbxassetid://2161586632",
		LayoutOrder = 3,
		IconPosition = UDim2.fromScale(0.495312, 0.481),
		IconSize = UDim2.fromScale(0.542942, 0.75),
		LabelPosition = UDim2.fromScale(0.499999, 0),
		ButtonPosition = UDim2.fromScale(0.418851, 0.25),
		ButtonSize = UDim2.fromScale(0.242, 0.75),
	},
	{
		Id = "Inventory",
		Label = "BACKPACK",
		Icon = "rbxassetid://18245740340",
		LayoutOrder = 2,
		IconPosition = UDim2.fromScale(0.493847, 0.484),
		IconSize = UDim2.fromScale(0.496643, 0.66),
		LabelPosition = UDim2.fromScale(0.5, 0),
		ButtonPosition = UDim2.fromScale(0.418851, 0.25),
		ButtonSize = UDim2.fromScale(0.242, 0.75),
		ZIndex = -5,
		Enabled = true,
	},
	{
		Id = "Shop",
		Label = "SHOP",
		Icon = "rbxassetid://18136118615",
		LayoutOrder = 1,
		IconPosition = UDim2.fromScale(0.47, 0.5),
		IconSize = UDim2.fromScale(0.486154, 0.628),
		LabelPosition = UDim2.fromScale(0.465819, 0),
		ButtonPosition = UDim2.fromScale(0.418851, 0.25),
		ButtonSize = UDim2.fromScale(0.242, 0.75),
		Enabled = true,
	},
	{
		Id = "SplashScreen",
		Label = "LOBBY",
		Icon = "rbxassetid://8517323790",
		IconPosition = UDim2.fromScale(0.5, 0.5),
		IconSize = UDim2.fromScale(0.410489, 0.5),
		LabelPosition = UDim2.fromScale(0.5, 0),
		ButtonPosition = UDim2.fromScale(0.120503, 0.125),
		ButtonSize = UDim2.fromScale(0.242138, 0.75),
		Enabled = true,
	},
}

export type Props = {
	CurrentPage: string,
	OnNavigate: (string) -> (),
	Tabs: { TabDefinition }?,
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.DeviceSafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local definitions = props.Tabs or DEFINITIONS
	local gap = if portrait then UIConfig.Layout.TopBar.PortraitGapScale else UIConfig.Layout.TopBar.LandscapeGapScale
	local buttonWidth = math.max((1 - gap * math.max(#definitions - 1, 0)) / math.max(#definitions, 1), 0)
	local buttons = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(gap, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for _, definition in definitions do
		local selected = definition.Id == props.CurrentPage
		local enabled = definition.Enabled ~= false
		buttons[definition.Id] = c(AnimatedButton, {
			ButtonRef = definition.ButtonRef,
			Enabled = enabled,
			Native = {
				BackgroundTransparency = 1,
				Image = if selected then SELECTED else UNSELECTED,
				ImageColor3 = if enabled then Color3.new(1, 1, 1) else Color3.fromRGB(145, 145, 145),
				LayoutOrder = definition.LayoutOrder,
				Position = definition.ButtonPosition or UDim2.fromScale(0.418851, 0.25),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(
					buttonWidth,
					if definition.ButtonSize then definition.ButtonSize.Y.Scale else 0.75
				),
				SliceCenter = Rect.new(224, 202, 770, 474),
				SliceScale = 0.2,
				ZIndex = definition.ZIndex,
			},
			OnActivated = function()
				props.OnNavigate(definition.Id)
			end,
			OnSelectionGained = definition.OnSelectionGained,
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 1.3 }),
			ImageLabel = c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = definition.Icon,
				ImageColor3 = if enabled then Color3.new(1, 1, 1) else Color3.fromRGB(190, 190, 190),
				ImageTransparency = if enabled then 0 else 0.18,
				LayoutOrder = 2,
				Position = definition.IconPosition or UDim2.fromScale(0.5, 0.5),
				Size = definition.IconSize or UDim2.fromScale(0.5, 0.65),
			}),
			Label = c(ResponsiveText, {
				HostName = "Label",
				MeasurementFont = Enum.Font.SourceSansBold,
				Native = {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = definition.LabelPosition or UDim2.fromScale(0.5, 0),
					Size = definition.LabelSize
						or UDim2.fromScale(1.4, if definition.Id == "Inventory" then 0.420305 else 0.42),
					Text = definition.Label,
					TextColor3 = if enabled then Color3.new(1, 1, 1) else Color3.fromRGB(185, 185, 185),
					TextTransparency = if enabled then 0 else 0.12,
				},
			}),
		})
	end

	return c("Frame", {
		BackgroundColor3 = Color3.fromRGB(63, 63, 63),
		BorderColor3 = Color3.new(),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.113754),
	}, {
		PageTabs = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.62),
			SelectionGroup = true,
			Size = UDim2.fromScale(
				if portrait
					then UIConfig.Layout.TopBar.PortraitWidthScale
					else UIConfig.Layout.TopBar.LandscapeWidthScale,
				0.877073
			),
		}, buttons),
	})
end
