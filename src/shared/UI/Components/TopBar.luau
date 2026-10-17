-- Description: The persistent top bar showing balances and the menu navigation actions.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local T = require(script.Parent.Parent.Tokens)
local LobbyNavigation = require(script.Parent.LobbyNavigation)
local LobbyHeader = require(script.Parent.LobbyHeader)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement

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
	LobbyHeader: boolean?,
	HeaderVisible: boolean?,
	-- LB/RB tab cycling (and its glyphs) while nothing modal sits above the rail.
	CycleEnabled: boolean?,
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local short = not portrait and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local definitions = props.Tabs or DEFINITIONS
	if props.LobbyHeader then
		return c(LobbyHeader, {
			CurrentPage = props.CurrentPage,
			OnNavigate = props.OnNavigate,
			Tabs = definitions,
			Visible = props.HeaderVisible,
			CycleEnabled = props.CycleEnabled,
		})
	end
	local count = math.max(#definitions, 1)
	local bandHeight = if short then UIConfig.Layout.TopBar.ShortHeightPx else safeArea.size.Y * 0.113754
	local nav = T.LobbyNavigation
	local navHeight = math.clamp(bandHeight - nav.MobileBandPadding * 6, nav.MobileHeight, nav.Height)
	local compact = navHeight < nav.Height - 8 or safeArea.size.X < 860
	local iconOnly = safeArea.size.X < count * 112 / 2 + nav.MobileEdge * 2 + 120
	local navWidth = if compact
		then math.min(safeArea.size.X - nav.MobileEdge * 2, count * 112)
		else math.min(safeArea.size.X * nav.WidthFraction, nav.MaxWidth, safeArea.size.X - nav.MobileEdge * 2)
	if iconOnly then
		navWidth = count * T.Layout.MinTarget + (count - 1) * nav.MobileEdge
	end
	navWidth = math.max(navWidth, count * T.Layout.MinTarget)

	return c("Frame", {
		BackgroundColor3 = T.Colors.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, bandHeight),
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
		PageTabs = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(
				safeArea.position.X + (safeArea.size.X - navWidth) / 2,
				(bandHeight - navHeight) / 2
			),
			SelectionGroup = true,
			Size = UDim2.fromOffset(navWidth, navHeight),
		}, {
			Navigation = c(LobbyNavigation, {
				Tabs = definitions,
				CurrentPage = props.CurrentPage,
				OnNavigate = props.OnNavigate,
				Width = navWidth,
				Compact = compact,
				IconOnly = iconOnly,
				CycleEnabled = props.CycleEnabled,
			}),
		}),
	})
end
