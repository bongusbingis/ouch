-- Name: ShopCard.luau
-- Author: Jack C.
-- Description: One storefront card: the item preview, name, price button, and the placeholder or preview state for offers that are not yet purchasable.
-- Created: 2026-08-23

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Inventory"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop"))
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local ShopPriceButton = require(script.Parent.ShopPriceButton)
local ShopPreview = require(script.Parent.ShopPreview)

local c = React.createElement

local CATEGORY_COLORS = {
	Crate = Color3.fromRGB(53, 226, 218),
	Bonks = Color3.fromRGB(255, 220, 62),
	Bundle = Color3.fromRGB(242, 24, 76),
	GamePass = Color3.fromRGB(209, 18, 252),
	SeasonPass = Color3.fromRGB(209, 18, 252),
	Cosmetic = Color3.fromRGB(53, 226, 218),
}

local function colorFor(card): Color3
	return InventoryConfig.RarityColors[card.badge] or CATEGORY_COLORS[card.kind] or Color3.fromRGB(97, 255, 237)
end

local function actionText(card): string
	if card.pending then
		return "PLEASE WAIT"
	end
	if card.owned then
		return "OWNED"
	end
	if card.status == "Preview" then
		return "COMING SOON"
	end
	if card.status == "Loading" then
		return "LOADING"
	end
	if card.status == "Unavailable" then
		return "UNAVAILABLE"
	end
	if card.kind == "Crate" then
		return "VIEW ODDS"
	end
	if card.bonksPrice ~= nil then
		return `{card.bonksPrice} BONKS`
	end
	if card.robuxPrice ~= nil then
		return `{ShopConfig.RobuxSymbol}{card.robuxPrice}`
	end
	return "VIEW"
end

local function placeholderText(card): string
	if card.kind == "Bonks" and card.definition.BonksAmount then
		return `{card.definition.BonksAmount} BONKS`
	end
	if card.kind == "Crate" then
		return string.upper((string.gsub(card.displayName, "[Cc][Rr][Aa][Tt][Ee]", "")))
	end
	if card.kind == "Bundle" then
		return "WEEKLY BUNDLE"
	end
	return card.badge or string.upper(card.kind)
end

return React.memo(function(props)
	local card = props.Card
	local hasHint = card.hintText ~= nil and card.hintText ~= ""
	local canAfford = card.kind == "Crate" or card.robuxPrice ~= nil or card.bonksPrice == nil or card.affordable
	local enabled = card.status == "Active" and not card.owned and not card.pending and canAfford
	return c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://123285423801571",
		ImageTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(1, 1),
		SliceCenter = Rect.new(107, 27, 126, 128),
		ZIndex = 4,
	}, {

		Preview = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.12, 0.12),
			Size = UDim2.fromScale(0.8, 0.4),
			ZIndex = 5,
		}, {
			Content = c(ShopPreview, {
				Items = card.previewItems,
				Thumbnail = card.thumbnail,
				Placeholder = placeholderText(card),
				ZIndex = 5,
			}),
		}),

		Badge = if card.badge
			then c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 20,
				Native = {
					AnchorPoint = Vector2.new(0, 0.5),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Color3.fromRGB(52, 52, 52),
					BackgroundTransparency = 0.12,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.04, 0.12),
					Size = UDim2.fromScale(0, 0.125),
					Text = string.upper(card.badge),
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 8,
				},
			}, {
				UICorner = c("UICorner", { CornerRadius = UDim.new(0.35, 0) }),
				UIPadding = c("UIPadding", {
					PaddingBottom = UDim.new(0, 2),
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 2),
				}),
			})
			else nil,

		Background = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://80477338860845",
			ImageColor3 = colorFor(card),
			ImageTransparency = if enabled then 0 else 0.16,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.96, 0.955),
			ZIndex = 4,
		}, {
			UIPadding = c("UIPadding", {
				PaddingBottom = UDim.new(0.03, 0),
				PaddingLeft = UDim.new(0, 0),
				PaddingRight = UDim.new(0, 0),
				PaddingTop = UDim.new(0.03, 0),
			}),

			UICorner = c("UICorner", { CornerRadius = UDim.new(0.04, 0) }),

			UIStroke = c("UIStroke", {
				Color = colorFor(card):Lerp(Color3.fromRGB(255, 255, 255), 0.5),
				Thickness = 0.02,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			}),

			Texture = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://6794188517",
				ImageTransparency = 0.9,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(264, 264),
			}),

			InfoBackdrop = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(32, 39, 48),
				BackgroundTransparency = 0.18,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, if hasHint then 0.545 else 0.61),
				Size = UDim2.fromScale(0.92, if hasHint then 0.42 else 0.355),
				ZIndex = 6,
			}, {
				UICorner = c("UICorner", { CornerRadius = UDim.new(0.08, 0) }),
			}),
			Name = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 30,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, if hasHint then 0.57 else 0.635),
					Size = UDim2.fromScale(0.86, 0.13),
					Text = string.upper(card.displayName),
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 8,
				},
			}, {
				UIStroke = c("UIStroke", {
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.047,
				}),
			}),
			SupportingText = if hasHint
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MaxTextSize = 18,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/SourceSansPro.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.5, 0.68),
						Size = UDim2.fromScale(0.84, 0.1),
						Text = card.hintText,
						TextColor3 = Color3.fromRGB(238, 248, 255),
						TextTransparency = 0.04,
						ZIndex = 8,
					},
				})
				else nil,
			Action = c(ShopPriceButton, {
				EntranceDelay = if props.LayoutOrder then (props.LayoutOrder - 1) * 0.035 else nil,
				Enabled = enabled,
				Text = actionText(card),
				Position = UDim2.fromScale(0.5, 0.955),
				Size = UDim2.fromScale(0.8, 0.165),
				OnActivated = function()
					props.OnActivated(card)
				end,
			}),
		}),
	})
end)
