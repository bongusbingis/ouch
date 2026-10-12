-- Displays the local party code and toggles its visibility without owning party state.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local CandySurface = require(script.Parent.CandySurface)
local PuffyButton = require(script.Parent.PuffyButton)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local T = require(script.Parent.Parent.Tokens)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c, C, S = React.createElement, T.Colors, T.Shape

export type Props = {
	CodeText: string,
	CodeVisible: boolean,
	OnToggle: () -> (),
	OnOpen: (() -> ())?,
	Compact: boolean?,
	Size: UDim2?,
	Label: string?,
	Position: any?,
}

-- Largest candy size that keeps the whole string inside the face; never below the menu floor.
local function fittedSize(text: string, font: Enum.Font, width: number, sizes: { number }): number
	for _, size in sizes do
		if TextService:GetTextSize(text, size, font, Vector2.new(100000, 1000)).X <= width then
			return size
		end
	end
	return T.Type.Minimum
end

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local short = props.Compact == true
		or (not portrait and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx)
	if short then
		local size = props.Size
			or UDim2.fromOffset(UIConfig.Layout.PartyCode.LandscapeWidthPx * 0.7, T.Layout.MinTarget)
		local label = props.Label
			or if props.OnOpen
				then "PARTY CODE"
				elseif props.CodeVisible then (string.gsub(props.CodeText, "^PARTY CODE:%s*", ""))
				else "PARTY CODE"
		return c(PuffyButton, {
			Color = C.Yellow,
			LipColor = C.YellowLip,
			StrokeColor = T.LobbyNavigation.Rim,
			Text = label,
			TextColor = C.Ink,
			TextSize = fittedSize(
				label,
				T.Type.Display,
				size.X.Offset - T.Layout.CompactGap - S.StrokeTab * 2,
				{ T.Type.Body, T.Type.Minimum }
			),
			OnActivated = props.OnOpen or props.OnToggle,
			Shadow = false,
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				Position = props.Position or UDim2.new(1, -T.LobbyNavigation.MobileEdge, 0, T.Layout.CompactGap),
				Size = size,
			},
		})
	end
	local codeHeight = if portrait
		then UIConfig.Layout.PartyCode.CodeHeightPx
		else UIConfig.Layout.PartyCode.LandscapeCodeHeightPx
	local width = if portrait then nil else UIConfig.Layout.PartyCode.LandscapeWidthPx
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.fromScale(if portrait then 0.74 else 0.5, 0.115),
		Size = if portrait
			then UDim2.new(0.44, 0, 0, UIConfig.Layout.PartyCode.PortraitHeightPx)
			else UDim2.fromOffset(
				UIConfig.Layout.PartyCode.LandscapeWidthPx,
				codeHeight + T.Layout.MinTarget + T.Layout.CompactGap / 2
			),
	}, {
		UIListLayout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, T.Layout.CompactGap / 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Code = c("Frame", {
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, codeHeight),
		}, {
			Surface = c(CandySurface, {
				Color = C.Surface,
				LipColor = C.WellLine,
				StrokeColor = T.LobbyNavigation.Rim,
				Shadow = false,
			}),
			Text = c("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(T.Layout.CompactGap / 2, 0),
				Size = UDim2.new(1, -T.Layout.CompactGap, 1, -S.LipHeight),
				Font = T.Type.Display,
				Text = props.CodeText,
				TextColor3 = C.Ink,
				TextSize = if width
					then fittedSize(
						props.CodeText,
						T.Type.Display,
						width - T.Layout.CompactGap - S.StrokeTab * 2,
						{ T.Type.TileLabel, T.Type.Body, T.Type.Minimum }
					)
					else T.Type.Section,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 5,
			}),
		}),
		ShowCode = c(PuffyButton, {
			Color = C.Pink,
			LipColor = C.PinkLip,
			StrokeColor = T.LobbyNavigation.Rim,
			Text = if props.CodeVisible then "HIDE CODE" else "SHOW CODE",
			TextSize = T.Type.Body,
			OnActivated = props.OnToggle,
			Shadow = false,
			Native = {
				LayoutOrder = 2,
				Size = UDim2.new(if portrait then 0.42 else 0.62, 0, 0, T.Layout.MinTarget),
			},
		}, {
			UIAspectRatioConstraint = if portrait then c("UIAspectRatioConstraint", { AspectRatio = 2.86 }) else nil,
			UISizeConstraint = c("UISizeConstraint", { MinSize = Vector2.new(0, T.Layout.MinTarget) }),
		}),
	})
end
