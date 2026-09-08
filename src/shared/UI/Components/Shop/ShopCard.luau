-- Description: One storefront card, in either of the two compositions its class asks for: artwork stacked over the copy for grid cards, or set beside it for the shallow scan rows and promotional banners.

--!strict

local formatNumber = require(script.Parent.Parent.Parent.Models.NumberText)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local BonksLabel = require(script.Parent.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local ShopPriceButton = require(script.Parent.ShopPriceButton)
local ShopPreview = require(script.Parent.ShopPreview)
local ShopLayout = require(script.Parent.Parent.Parent.Models.ShopLayout)

local c = React.createElement
local Palette = UIConfig.ProgressionStyle

local CATEGORY_COLORS = {
	Crate = Color3.fromRGB(53, 226, 218),
	Bonks = Color3.fromRGB(255, 220, 62),
	Bundle = Color3.fromRGB(242, 24, 76),
	GamePass = Color3.fromRGB(209, 18, 252),
	SeasonPass = Color3.fromRGB(209, 18, 252),
	Cosmetic = Color3.fromRGB(53, 226, 218),
}

-- The coloured panel and its padding are the box every offset inside a card is
-- measured against, so its height is derived once rather than assumed twice.
local BACKGROUND_HEIGHT_SCALE = 0.955
local BACKGROUND_PADDING_SCALE = 0.03
local BAND_GAP = 3
-- Artwork never gives up more than this share of a stacked card; the supporting
-- line is what goes first when the card is short.
local MIN_ART_SHARE = 0.34

local function innerHeight(cardHeight: number): number
	return math.max(math.floor(cardHeight * BACKGROUND_HEIGHT_SCALE * (1 - BACKGROUND_PADDING_SCALE * 2)), 1)
end

local function colorFor(card): Color3
	return InventoryConfig.RarityColors[card.badge] or CATEGORY_COLORS[card.kind] or Color3.fromRGB(97, 255, 237)
end

local function bandColor(card): Color3
	local hue, saturation, value = colorFor(card):ToHSV()
	return Color3.fromHSV(hue, math.min(saturation * 1.15, 1), math.max(value * 0.82, 0.65))
end

-- A crate opens its odds sheet, so that is what its button says -- unless the
-- card is too shallow for the supporting line that carries the price, in which
-- case the button is the only place left to show it.
local function actionContent(card, hasHint: boolean): (string?, number?)
	if card.pending then
		return "PLEASE WAIT", nil
	end
	if card.owned then
		return "OWNED", nil
	end
	if card.status == "Preview" then
		return "COMING SOON", nil
	end
	if card.status == "Loading" then
		return "LOADING", nil
	end
	if card.status == "Unavailable" then
		return "UNAVAILABLE", nil
	end
	if card.kind == "Crate" and hasHint then
		return "VIEW ODDS", nil
	end
	if card.bonksPrice ~= nil then
		return nil, card.bonksPrice
	end
	if card.robuxPrice ~= nil then
		return `{ShopConfig.RobuxSymbol}{formatNumber(card.robuxPrice)}`, nil
	end
	if card.kind == "Crate" then
		return "VIEW ODDS", nil
	end
	return "VIEW", nil
end

local function placeholderBonks(card): number?
	return if card.kind == "Bonks" then card.definition.BonksAmount else nil
end

local function placeholderText(card): string
	if card.kind == "Crate" then
		return string.upper((string.gsub(card.displayName, "[Cc][Rr][Aa][Tt][Ee]", "")))
	end
	if card.kind == "Bundle" then
		return "OUTFIT SET"
	end
	return card.badge or string.upper(card.kind)
end

local function hasArtwork(card): boolean
	return (card.thumbnail ~= nil and card.thumbnail ~= "") or #card.previewItems > 0
end

type Bands = {
	action: number,
	name: number,
	hint: number,
	art: number,
	info: number,
}

-- Every band is sized in pixels off the card's own height rather than as a share
-- of it, because a class that has squared up on a narrow column no longer has
-- the proportions a scale offset assumed. The supporting line is included only
-- when what remains still leaves the artwork room to read.
local function bands(class, card, height: number): Bands
	local inner = innerHeight(height)
	local action = math.clamp(math.floor(height * class.ActionScale), class.ActionMinPx, class.ActionMaxPx)
	local name = if class.Layout == "Split" then 40 else 42
	local hint = 22
	local budget = if class.Layout == "Split"
		then math.floor(inner * 0.84)
		else inner - math.floor(inner * MIN_ART_SHARE) - 5
	-- Whether a class carries the supporting line is a property of the class, not
	-- of the width it happens to be rendered at, so the same offer never says one
	-- thing on a laptop and another on a desktop. The fit check is only a guard.
	local wanted = class.ShowHint == true and card.hintText ~= nil and card.hintText ~= ""
	local showHint = wanted and name + BAND_GAP + hint + BAND_GAP + action <= budget
	local info = action + BAND_GAP + name + (if showHint then hint + 2 else 0) + 12
	return {
		action = action,
		name = name,
		hint = if showHint then hint else 0,
		art = math.max(inner - info - 5, 10),
		info = info,
	}
end

local function nameLabel(card, class, native, alignment: Enum.TextXAlignment): any
	local merged = table.clone(native)
	merged.BackgroundTransparency = 1
	merged.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	merged.Text = string.upper(card.displayName)
	merged.TextColor3 = Color3.new(1, 1, 1)
	merged.TextXAlignment = alignment
	merged.TextWrapped = true
	merged.ZIndex = 8
	return c(ResponsiveText, {
		HostName = "Name",
		MeasurementFont = Enum.Font.LuckiestGuy,
		MinTextSize = 15,
		MaxTextSize = 21,
		Wrapped = true,
		Native = merged,
	}, {
		UIStroke = c("UIStroke", {
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.047,
		}),
	})
end

local function hintLabel(card, native, alignment: Enum.TextXAlignment): any
	local merged = table.clone(native)
	merged.BackgroundTransparency = 1
	merged.Font = UIConfig.Text.BodyFont
	merged.Text = if card.kind == "Bundle" then "OUTFIT BUNDLE" else card.hintText
	merged.TextColor3 = Palette.White
	merged.TextStrokeColor3 = Palette.Ink
	merged.TextStrokeTransparency = 0.35
	merged.TextTransparency = 0.04
	merged.TextXAlignment = alignment
	merged.ZIndex = 8
	return c(ResponsiveText, {
		HostName = "SupportingText",
		MeasurementFont = UIConfig.Text.BodyFont,
		MaxTextSize = 18,
		Native = merged,
	})
end

local function badgeLabel(card): any
	return c(ResponsiveText, {
		HostName = "Badge",
		MeasurementFont = UIConfig.Text.BodyFont,
		MaxTextSize = 16,
		Native = {
			AnchorPoint = Vector2.new(0, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = bandColor(card),
			BackgroundTransparency = 0,
			Font = UIConfig.Text.BodyFont,
			Position = UDim2.new(0.05, 0, 0, 4),
			Size = UDim2.fromOffset(0, 16),
			Text = string.upper(card.badge),
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Palette.Ink,
			TextStrokeTransparency = 0.35,
			ZIndex = 8,
		},
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
		UIPadding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
end

local function artwork(card, position: UDim2, size: UDim2): any
	local items = card.previewItems
	if #items > 1 then
		local hero = items[1]
		for _, item in items do
			if item.category == "CostumeAssets" then
				hero = item
				break
			end
		end
		items = { hero }
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		ZIndex = 5,
	}, {
		Content = c(ShopPreview, {
			Items = items,
			Thumbnail = card.thumbnail,
			Placeholder = placeholderText(card),
			PlaceholderBonks = placeholderBonks(card),
			ZIndex = 5,
		}),
	})
end

local function infoBackdrop(card, anchor: Vector2, position: UDim2, size: UDim2): any
	return c("Frame", {
		AnchorPoint = anchor,
		BackgroundColor3 = bandColor(card),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		ZIndex = 6,
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(0.16, 0) }),
	})
end

local function priceButton(card, band: Bands, enabled: boolean, native, onActivated, layoutOrder): any
	local text, bonks = actionContent(card, band.hint > 0)
	local merged = table.clone(native)
	merged.EntranceDelay = if layoutOrder then (layoutOrder - 1) * 0.03 else nil
	merged.Enabled = enabled
	merged.Text = text
	merged.BonksAmount = bonks
	merged.OnActivated = onActivated
	merged.Compact = true
	merged.TextSize = 20
	merged.Color = if card.owned then Palette.Claimed else Palette.Cyan
	return c(ShopPriceButton, merged)
end

-- Where a supporting line exists at all it carries the offer's Bonks price, so
-- a card that has one is written as the coin, the price being charged, and --
-- when the offer is discounted -- what it was, rather than spelling the
-- currency out in words.
local function pricedHint(card): boolean
	return card.bonksPrice ~= nil
end

local function priceLine(card, native, alignment: Enum.TextXAlignment): any
	local merged = table.clone(native)
	merged.BackgroundTransparency = 1
	merged.ZIndex = 8
	return c("Frame", merged, {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if alignment == Enum.TextXAlignment.Left
				then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Price = c(BonksLabel, {
			Amount = card.bonksPrice,
			MaxTextSize = 20,
			TextColor = Palette.White,
			TextStroke = 0.045,
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.fromScale(if card.originalBonksPrice then 0.4 else 0.6, 1),
			},
		}),
		Was = if card.originalBonksPrice == nil
			then nil
			else c(ResponsiveText, {
				HostName = "Was",
				MeasurementFont = UIConfig.Text.BodyFont,
				MaxTextSize = 16,
				Native = {
					BackgroundTransparency = 1,
					Font = UIConfig.Text.BodyFont,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0.44, 0.86),
					Text = `WAS {formatNumber(card.originalBonksPrice)}`,
					TextColor3 = Palette.White,
					TextStrokeColor3 = Palette.Ink,
					TextStrokeTransparency = 0.35,
					TextXAlignment = alignment,
					ZIndex = 8,
				},
			}),
	})
end

local function stackContent(card, class, band: Bands, enabled: boolean, onActivated, layoutOrder)
	return {
		Artwork = artwork(card, UDim2.new(0.06, 0, 0, 3), UDim2.new(0.88, 0, 0, band.art)),
		InfoBackdrop = infoBackdrop(
			card,
			Vector2.new(0.5, 1),
			UDim2.new(0.5, 0, 1, -1),
			UDim2.new(0.94, 0, 0, band.info)
		),
		Name = nameLabel(card, class, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(
				0.5,
				0,
				1,
				-(8 + band.action + BAND_GAP + (if band.hint > 0 then band.hint + 2 else 0))
			),
			Size = UDim2.new(0.88, 0, 0, band.name),
		}, Enum.TextXAlignment.Center),
		SupportingText = if band.hint > 0
			then (if pricedHint(card) then priceLine else hintLabel)(card, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -(8 + band.action + BAND_GAP)),
				Size = UDim2.new(0.86, 0, 0, band.hint),
			}, Enum.TextXAlignment.Center)
			else nil,
		Action = priceButton(card, band, enabled, {
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(0.86, 0, 0, band.action),
		}, onActivated, layoutOrder),
	}
end

-- Scan-row and banner composition: artwork on the left, the copy stacked beside
-- it. A card with no artwork of its own gives the whole width to the copy rather
-- than reserving a box for a placeholder no one can read at this height.
local function splitContent(card, class, band: Bands, enabled: boolean, onActivated, layoutOrder)
	local art = if hasArtwork(card) then class.ArtScale else 0
	local infoX = if art > 0 then 0.03 + art + 0.03 else 0.04
	local infoWidth = 0.96 - infoX
	return {
		Artwork = if art > 0 then artwork(card, UDim2.fromScale(0.03, 0.08), UDim2.fromScale(art, 0.84)) else nil,
		InfoBackdrop = infoBackdrop(
			card,
			Vector2.new(0, 0.5),
			UDim2.fromScale(infoX, 0.5),
			UDim2.fromScale(infoWidth, 0.88)
		),
		Info = c("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(infoX + 0.03, 0.5),
			Size = UDim2.fromScale(infoWidth - 0.06, 0.84),
			ZIndex = 7,
		}, {
			UIListLayout = c("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, BAND_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Name = nameLabel(card, class, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, band.name),
			}, Enum.TextXAlignment.Left),
			SupportingText = if band.hint > 0
				then (if pricedHint(card) then priceLine else hintLabel)(card, {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, band.hint),
				}, Enum.TextXAlignment.Left)
				else nil,
			Action = priceButton(card, band, enabled, {
				AnchorPoint = Vector2.new(0, 0),
				LayoutOrder = 3,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.new(1, 0, 0, band.action),
			}, onActivated, layoutOrder),
		}),
	}
end

export type Props = {
	Card: any,
	Class: any,
	CardHeight: number,
	LayoutOrder: number?,
	OnActivated: (any) -> (),
}

return React.memo(function(props: Props)
	local card = props.Card
	local class = props.Class
	local stacked = class.Layout ~= "Split"
	local enabled = true
	local band = bands(class, card, props.CardHeight)
	local onActivated = function()
		props.OnActivated(card)
	end
	local background = if stacked
		then stackContent(card, class, band, enabled, onActivated, props.LayoutOrder)
		else splitContent(card, class, band, enabled, onActivated, props.LayoutOrder)
	background.UIPadding = c("UIPadding", {
		PaddingBottom = UDim.new(BACKGROUND_PADDING_SCALE, 0),
		PaddingTop = UDim.new(BACKGROUND_PADDING_SCALE, 0),
	})
	background.UICorner = c("UICorner", { CornerRadius = UDim.new(0.07, 0) })
	background.UIStroke = c("UIStroke", {
		Color = colorFor(card):Lerp(Color3.fromRGB(255, 255, 255), 0.5),
		Thickness = 0.025,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
	})
	background.Texture = c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://6794188517",
		ImageTransparency = 0.9,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(264, 264),
	})

	return c("ImageLabel", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Image = "rbxassetid://123285423801571",
		ImageTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(1, 1),
		SliceCenter = Rect.new(107, 27, 126, 128),
		ZIndex = 4,
	}, {
		-- The badge pill only earns its place over real artwork: an offer with
		-- none already fills that space with the same word, and the shallow
		-- composition is named by its section header instead.
		Badge = if card.badge and stacked and hasArtwork(card) then badgeLabel(card) else nil,

		Background = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://80477338860845",
			ImageColor3 = colorFor(card),
			ImageTransparency = if enabled then 0 else 0.16,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.96, BACKGROUND_HEIGHT_SCALE),
			ZIndex = 4,
		}, background),
	})
end)
