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

-- Grouped in thousands wherever it is shown, so a balance and a price of the
-- same magnitude are read the same way.
local function formatAmount(value: number): string
	local out = tostring(math.floor(value))
	while true do
		local replaced, count = string.gsub(out, "^(%-?%d+)(%d%d%d)", "%1,%2")
		out = replaced
		if count == 0 then
			return out
		end
	end
end

export type Props = {
	Amount: number,
	Native: { [any]: any }?,
	TextColor: Color3?,
	IconSize: UDim2?,
	MaxTextSize: number?,
	TextStroke: number?,
	StackThreshold: number?,
	StackIconAsset: string?,
	children: { [any]: any }?,
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

	local children = {
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
			MaxTextSize = props.MaxTextSize,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.7, 0.8),
				Text = formatAmount(props.Amount),
				TextColor3 = props.TextColor or BONKS_COLOR,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}, {
			-- Callers that sit the amount on a button match that button's own
			-- outlined type rather than reading as a plain number beside it.
			UIStroke = if props.TextStroke
				then c("UIStroke", {
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = props.TextStroke,
				})
				else nil,
		}),
	}
	-- Callers decorate the container itself (a corner, a stroke), so their own
	-- children sit alongside the icon and the amount rather than replacing them.
	if props.children then
		for key, value in props.children do
			children[key] = value
		end
	end

	return c("Frame", container, children)
end
