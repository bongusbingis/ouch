-- Name: ShopPriceButton.luau
-- Author: Jack C.
-- Description: The price button on a storefront card, rendering the currency, amount, any discount, and its pending or disabled state.
-- Created: 2026-08-23

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

return function(props)
	local stacked = props.SubText ~= nil or props.SubBonks ~= nil
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
		-- A Bonks amount is shown as the coin plus the number, never as the word:
		-- the currency reads at a glance and the button keeps the same footprint
		-- whichever currency it is priced in.
		BonksLabel = if props.BonksAmount
			then c(BonksLabel, {
				Amount = props.BonksAmount,
				MaxTextSize = if stacked then 26 else 28,
				TextColor = props.BonksColor or Color3.new(1, 1, 1),
				TextStroke = 0.06,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = if stacked then UDim2.fromScale(0.5, 0.4) else UDim2.fromScale(0.5, 0.56),
					Size = if stacked then UDim2.fromScale(0.88, 0.38) else UDim2.fromScale(0.88, 0.6),
					ZIndex = (props.ZIndex or 8) + 1,
				},
			})
			else nil,
		TextLabel = if props.BonksAmount
			then nil
			else c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = if stacked then 26 else 28,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = if stacked then UDim2.fromScale(0.5, 0.4) else UDim2.fromScale(0.5, 0.56),
					Size = if stacked then UDim2.fromScale(0.88, 0.38) else UDim2.fromScale(0.88, 0.6),
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
		SubBonksLabel = if props.SubBonks
			then c(BonksLabel, {
				Amount = props.SubBonks,
				MaxTextSize = props.SubTextSize or 20,
				TextColor = props.SubTextColor or Color3.fromRGB(255, 240, 190),
				TextStroke = 0.08,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.72),
					Size = UDim2.fromScale(0.88, 0.3),
					ZIndex = (props.ZIndex or 8) + 1,
				},
			})
			else nil,
		SubLabel = if props.SubText and not props.SubBonks
			then c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = props.SubTextSize or 20,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.5, 0.72),
					Size = UDim2.fromScale(0.88, 0.3),
					Text = props.SubText,
					TextColor3 = props.SubTextColor or Color3.fromRGB(255, 240, 190),
					ZIndex = (props.ZIndex or 8) + 1,
				},
			}, {
				UIStroke = c("UIStroke", {
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),
			})
			else nil,
	})
end
