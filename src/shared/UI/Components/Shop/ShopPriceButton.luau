-- Name: ShopPriceButton.luau
-- Author: Jack C.
-- Description: The price button on a storefront card, rendering the currency, amount, any discount, and its pending or disabled state.
-- Created: 2026-08-23

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

return function(props)
	return c(AnimatedButton, {
		ButtonRef = props.ButtonRef,
		EntranceDelay = props.EntranceDelay,
		Enabled = props.Enabled,
		Style = "Standard",
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Image = props.Red and "rbxassetid://94748581468730" or "rbxassetid://136021539696619",
			ImageColor3 = if props.Enabled == false then Color3.fromRGB(135, 135, 135) else Color3.new(1, 1, 1),
			LayoutOrder = props.LayoutOrder,
			Position = props.Position or UDim2.fromScale(0.5, 0.95),
			ScaleType = Enum.ScaleType.Slice,
			Size = props.Size or UDim2.fromScale(0.78, 0.19),
			SliceCenter = Rect.new(198, 228, 841, 468),
			SliceScale = 0.12,
			ZIndex = props.ZIndex or 8,
		},
		OnActivated = props.OnActivated,
	}, {
		TextLabel = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 28,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.fromScale(0.82, 0.6),
				Text = props.Text,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = (props.ZIndex or 8) + 1,
			},
		}, {
			UIStroke = c("UIStroke", {
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.06,
			}),
		}),
	})
end
