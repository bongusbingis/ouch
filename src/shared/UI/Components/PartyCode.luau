-- Displays the local party code and toggles its visibility without owning party state.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ButtonSurface = require(script.Parent.ButtonSurface)
local ResponsiveText = require(script.Parent.OuchText)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement

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

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local short = props.Compact == true
		or (not portrait and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx)
	if short then
		return c(AnimatedButton, {
			OnActivated = props.OnOpen or props.OnToggle,
			SelectionRadius = UDim.new(0, 8),
			Visual = c(ButtonSurface, { Color = UIConfig.ProgressionStyle.Yellow, Radius = UDim.new(0, 8) }),
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = props.Position or UDim2.new(1, -8, 0, 14),
				Size = props.Size or UDim2.fromOffset(
					UIConfig.Layout.PartyCode.LandscapeWidthPx * 0.7,
					UIConfig.Interaction.MinTargetPx
				),
			},
		}, {
			Label = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 20,
				Native = {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(10, 3),
					Size = UDim2.new(1, -20, 1, -6),
					Font = Enum.Font.LuckiestGuy,
					Text = props.Label or if props.OnOpen
						then "PARTY CODE"
						elseif props.CodeVisible then string.gsub(props.CodeText, "^PARTY CODE:%s*", "")
						else "PARTY CODE",
					TextColor3 = UIConfig.ProgressionStyle.Ink,
					ZIndex = 2,
				},
			}),
		})
	end
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
