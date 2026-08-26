-- Name: CrateRevealModal.luau
-- Author: Jack C.
-- Description: Modal that reveals what a crate opening produced, showing the item preview, its rarity, and any duplicate refund.
-- Created: 2026-08-23

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Inventory"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)

local c = React.createElement

return function(props)
	local reveal = props.Reveal
	local buttonRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	React.useEffect(function()
		if reveal then
			previousSelection.current = GuiService.SelectedObject
			task.defer(function()
				local button = buttonRef.current
				if button and button.Parent and button.Selectable then
					GuiService.SelectedObject = button
				end
			end)
		else
			local previous = previousSelection.current
			previousSelection.current = nil
			if previous and previous.Parent and previous.Visible and previous.Selectable then
				GuiService.SelectedObject = previous
			end
		end
	end, { reveal })
	if reveal == nil then
		return nil
	end
	local subtitle = if reveal.isDupe then `DUPLICATE • +{reveal.bonksRefund} BONKS` else string.upper(reveal.rarity)
	return c("Frame", {
		Active = true,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.28,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 111,
	}, {
		Panel = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			ImageColor3 = InventoryConfig.RarityColors[reveal.rarity] or Color3.new(1, 1, 1),
			Position = UDim2.fromScale(0.5, 0.53),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.4, 0.54),
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
			ZIndex = 112,
		}, {
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 46,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.06),
					Size = UDim2.fromScale(0.88, 0.12),
					Text = "YOU GOT",
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}),
			Preview = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.16, 0.18),
				Size = UDim2.fromScale(0.68, 0.46),
				ZIndex = 113,
			}, {
				Content = c(ShopPreview, {
					Items = if reveal.preview then { reveal.preview } else {},
					Thumbnail = "",
					ZIndex = 113,
				}),
			}),
			Name = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 42,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.62),
					Size = UDim2.fromScale(0.9, 0.12),
					Text = string.upper(reveal.displayName),
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}),
			Subtitle = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 25,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.5, 0.74),
					Size = UDim2.fromScale(0.88, 0.08),
					Text = subtitle,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}),
			Confirm = c(ShopPriceButton, {
				ButtonRef = buttonRef,
				Enabled = true,
				Position = UDim2.fromScale(0.5, 0.94),
				Size = UDim2.fromScale(0.46, 0.13),
				Text = "AWESOME!",
				OnActivated = props.OnClose,
				ZIndex = 114,
			}),
		}),
	})
end
