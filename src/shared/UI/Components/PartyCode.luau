-- Name: PartyCode.luau
-- Author: Jack C.
-- Description: Displays the local party's join code with a copy action.
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

export type Props = {
	CodeText: string,
	CodeVisible: boolean,
	OnToggle: () -> (),
	Position: any?,
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.fromScale(if portrait then 0.74 else 0.5, 0.115),
		Size = if portrait
			then UDim2.new(0.44, 0, 0, UIConfig.Layout.PartyCode.PortraitHeightPx)
			else UDim2.fromOffset(
				UIConfig.Layout.PartyCode.LandscapeWidthPx,
				UIConfig.Layout.PartyCode.LandscapeCodeHeightPx + UIConfig.Interaction.MinTargetPx + 6
			),
	}, {
		UIListLayout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Code = c("ImageLabel", {
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Image = "rbxassetid://123095501298848",
			Position = UDim2.fromScale(0.365216, 0.0467871),
			Size = if portrait
				then UDim2.new(1, 0, 0, UIConfig.Layout.PartyCode.CodeHeightPx)
				else UDim2.new(1, 0, 0, UIConfig.Layout.PartyCode.LandscapeCodeHeightPx),
		}, {

			TextLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 40,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.541416),
					Size = UDim2.fromScale(0.95, 0.728),
					Text = props.CodeText,
					TextColor3 = Color3.new(1, 1, 1),
				},
			}),
		}),

		ShowCode = c(AnimatedButton, {
			Native = {
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Image = "rbxassetid://136731323162202",
				Position = UDim2.fromScale(0.433867, 0.634355),
				Size = if portrait
					then UDim2.new(0.42, 0, 0, UIConfig.Interaction.MinTargetPx)
					else UDim2.new(0.62, 0, 0, UIConfig.Interaction.MinTargetPx),
			},
			OnActivated = props.OnToggle,
		}, {
			TextLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 28,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.541416),
					Size = UDim2.fromScale(0.85, 0.728),
					Text = if props.CodeVisible then "HIDE CODE" else "SHOW CODE",
					TextColor3 = Color3.new(1, 1, 1),
				},
			}),
			UIAspectRatioConstraint = if portrait then c("UIAspectRatioConstraint", { AspectRatio = 2.86 }) else nil,
			UISizeConstraint = c("UISizeConstraint", {
				MinSize = Vector2.new(0, UIConfig.Interaction.MinTargetPx),
			}),
		}),
	})
end
