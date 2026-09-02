-- Name: BonksLabel.luau
-- Author: Jack C.
-- Description: Reusable currency display showing a coin icon and a formatted Bonks amount, used by splash panels, modals, and shop UI.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

local BONKS_ICON_ASSET = "rbxassetid://106703644238993"
local BONKS_COLOR = Color3.fromRGB(255, 211, 51)

export type Props = {
	Amount: number,
	Native: { [any]: any }?,
	TextColor: Color3?,
	IconSize: UDim2?,
	StackThreshold: number?,
	StackIconAsset: string?,
}

return function(props: Props)
	local icon = BONKS_ICON_ASSET
	if props.StackThreshold and props.StackIconAsset and props.Amount >= props.StackThreshold then
		icon = props.StackIconAsset
	end

	local container = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}
	if props.Native then
		for key, value in props.Native do
			container[key] = value
		end
	end

	return c("Frame", container, {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.05, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Icon = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = icon,
			LayoutOrder = 1,
			Size = props.IconSize or UDim2.fromScale(0.2, 0.8),
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
		}),
		Amount = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.7, 0.8),
				Text = tostring(props.Amount),
				TextColor3 = props.TextColor or BONKS_COLOR,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),
	})
end
