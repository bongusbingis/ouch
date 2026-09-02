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
	local safeArea = useSafeArea(Enum.ScreenInsets.DeviceSafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.fromScale(0.5, 0.115),
		Size = if portrait
			then UDim2.new(0.84, 0, 0, UIConfig.Layout.PartyCode.PortraitHeightPx)
			else UDim2.fromScale(0.4, 0.122814),
	}, {
		UIListLayout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = if portrait then UDim.new(0, 6) else UDim.new(0.04, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Code = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://123095501298848",
			Position = UDim2.fromScale(0.365216, 0.0467871),
			Size = if portrait
				then UDim2.new(0.72, 0, 0, UIConfig.Layout.PartyCode.CodeHeightPx)
				else UDim2.fromScale(0.397188, 1.08804),
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 4.18 }),
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
		UIPadding = c("UIPadding", { PaddingTop = if portrait then UDim.new(0, 0) else UDim.new(0.1, 0) }),
		ShowCode = c(AnimatedButton, {
			Native = {
				BackgroundTransparency = 1,
				Image = "rbxassetid://136731323162202",
				Position = UDim2.fromScale(0.433867, 0.634355),
				Size = if portrait
					then UDim2.new(0.42, 0, 0, UIConfig.Interaction.MinTargetPx)
					else UDim2.fromScale(0.161336, 0.704785),
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
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 2.86 }),
			UISizeConstraint = c("UISizeConstraint", {
				MinSize = Vector2.new(0, UIConfig.Interaction.MinTargetPx),
			}),
		}),
	})
end
