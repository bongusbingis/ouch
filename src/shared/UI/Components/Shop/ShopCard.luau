--!strict
-- Commercial card proportions are distinct; rarity and puffy surfaces are shared.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Parent.Tokens)
local ShopConfig = require(RS.Config.Economy.Shop)
local number = require(script.Parent.Parent.Parent.Models.NumberText)
local Preview = require(script.Parent.ShopPreview)
local PriceButton = require(script.Parent.ShopPriceButton)
local Ribbon = require(script.Parent.Parent.RarityRibbon)
local Surface = require(script.Parent.Parent.CandySurface)
local Progress = require(script.Parent.Parent.CandyProgressBar)
local UIFeedback = require(script.Parent.Parent.Parent.Services.UIFeedback)
local c, C, L = React.createElement, T.Colors, T.Shop
local accents = {
	SeasonPass = C.Gold,
	GamePass = C.Grape,
	Crate = C.Cyan,
	Bundle = C.Pink,
	Bonks = C.Yellow,
	Cosmetic = C.NeutralTile,
}
return React.memo(function(props)
	local card = props.Card
	local pointerHovered, setPointerHovered = React.useState(false)
	local actionHovered, setActionHovered = React.useState(false)
	local hovered = pointerHovered or actionHovered
	local season = card.kind == "SeasonPass"
	local width, height = props.CardWidth, props.CardHeight
	local short = height <= T.LobbyLandscape.CardHeight
	local split = (props.Class.Layout == "Split" or season) and width >= L.PromoMin
	local currency = card.kind == "Bonks"
	local owned = card.owned and not season
	local pad = L.CardPadding
	local infoX = if split then math.floor(width * L.SplitArtScale) else pad
	local infoWidth = width - infoX - pad
	local nameHeight = if short then 40 elseif height < 220 then 48 else L.NameHeight
	local actionHeight = L.ActionHeight
	local actionY = height - pad - actionHeight
	local artTop = if short then 44 else L.ArtTop
	local nameY = if split then artTop else actionY - nameHeight - pad
	local artBottom = if split then height - pad else nameY - pad
	local accent = accents[card.kind] or C.NeutralTile
	local background = accent:Lerp(C.Surface, 0.75)
	local text, amount
	if season then
		text = "VIEW REWARDS"
	elseif card.pending then
		text = "PROCESSING…"
	elseif card.owned then
		text = "VIEW ITEM"
	elseif card.status == "Preview" then
		text = "COMING SOON"
	elseif card.status == "Loading" then
		text = "LOADING…"
	elseif card.status == "Unavailable" then
		text = "UNAVAILABLE"
	elseif card.kind == "Crate" then
		text = "VIEW ODDS"
	elseif card.bonksPrice then
		amount = card.bonksPrice
	elseif card.robuxPrice then
		text = ShopConfig.RobuxSymbol .. number(card.robuxPrice)
	else
		text = "VIEW"
	end
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
	local badge = if season then "SEASON PASS" else card.badge or string.upper(card.kind)
	local rarity = if T.Rarity[card.badge] then card.badge else nil
	local state = if season and height >= 220 then props.SeasonState else nil
	local name = if season
			and props.SeasonState
			and props.SeasonState.active
		then string.upper(props.SeasonState.displayName)
		elseif state and state.active then string.upper(state.displayName)
		elseif currency then number(card.definition.BonksAmount or 0) .. " BONKS"
		else string.upper(card.displayName)
	local secondary = if season
		then (if card.owned then "PREMIUM OWNED" else "FREE + PREMIUM REWARDS")
		elseif card.originalBonksPrice then number(card.bonksPrice) .. " BONKS · WAS " .. number(
			card.originalBonksPrice
		)
		elseif card.kind == "Crate" and card.bonksPrice then number(card.bonksPrice) .. " BONKS / OPEN"
		else nil
	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		[React.Event.MouseEnter] = function()
			setPointerHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setPointerHovered(false)
		end,
	}, {
		Surface = c(Surface, {
			Color = background,
			Radius = T.Shape.RadiusCard,
			Shadow = false,
			StrokeColor = if hovered then C.Yellow else C.Ink,
			ZIndex = 4,
		}),
		Badge = if badge
			then c(Ribbon, {
				Text = badge,
				Rarity = rarity,
				Color = if season then C.Gold else nil,
				Native = {
					Position = UDim2.fromOffset(pad, L.BadgeTop),
					Size = UDim2.new(
						1,
						-pad * 2 - (if owned and split then L.OwnedWidth + L.BadgeGap else 0),
						0,
						L.BadgeHeight
					),
					ZIndex = 10,
				},
			})
			else nil,
		Owned = if owned
			then c(Ribbon, {
				Text = "OWNED",
				Color = C.Yellow,
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(
						1,
						-pad,
						0,
						if split then L.BadgeTop else L.BadgeTop + L.BadgeHeight + L.BadgeGap
					),
					Size = UDim2.fromOffset(L.OwnedWidth, L.BadgeHeight),
					ZIndex = 13,
				},
			})
			else nil,
		Artwork = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(pad, artTop),
			Size = UDim2.fromOffset(
				if split then infoX - pad * 2 else width - pad * 2 - (if owned then L.OwnedWidth + L.BadgeGap else 0),
				math.max(artBottom - artTop, 28)
			),
			ZIndex = 9,
		}, {
			Content = c(Preview, {
				Items = items,
				Playing = hovered,
				Thumbnail = card.thumbnail,
				Placeholder = card.badge,
				PlaceholderBonks = if currency then card.definition.BonksAmount else nil,
				ZIndex = 9,
			}),
		}),
		Name = c("TextLabel", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(infoX, nameY),
			Size = UDim2.fromOffset(infoWidth, nameHeight),
			Font = T.Type.Display,
			Text = name,
			TextSize = if short then T.Type.Minimum else T.Type.TileLabel,
			TextColor3 = C.Surface,
			TextWrapped = true,
			ZIndex = 12,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
			Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		}),
		Progress = if state and state.active
			then c(Progress, {
				Progress = if state.tier >= state.tierCount
					then 1
					else (state.xpIntoTier or 0) / math.max(state.xpForNextTier or 1, 1),
				Color = C.Pink,
				Native = {
					Position = UDim2.fromOffset(infoX, nameY + nameHeight + 12),
					Size = UDim2.fromOffset(infoWidth, 12),
					ZIndex = 12,
				},
			})
			else nil,
		SupportingText = if split
				and secondary
				and height >= 220
			then c("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(infoX, nameY + nameHeight + (if state and state.active then 30 else 8)),
				Size = UDim2.fromOffset(
					infoWidth,
					actionY - nameY - nameHeight - (if state and state.active then 38 else 16)
				),
				Font = T.Type.Label,
				Text = if state and state.active
					then "TIER " .. tostring(state.tier) .. " · " .. secondary
					else secondary,
				TextSize = T.Type.Minimum,
				TextColor3 = C.Ink,
				TextWrapped = true,
				ZIndex = 12,
			})
			else nil,
		-- The artwork/name affordance opens the same inspection as the footer.
		-- Keep sibling hitboxes separate and a single keyboard/controller stop.
		Inspect = c("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			Size = UDim2.new(1, 0, 0, actionY - T.Shape.StrokeCard * 2),
			ZIndex = 14,
			[React.Event.Activated] = function()
				UIFeedback.click()
				props.OnActivated(card)
			end,
		}),
		Action = c(PriceButton, {
			Text = text,
			BonksAmount = amount,
			TextSize = if infoWidth < 220 then T.Type.Minimum else T.Type.TileLabel,
			Color = if season then C.Pink else C.Surface,
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(infoX, actionY),
			Size = UDim2.fromOffset(infoWidth, actionHeight),
			ZIndex = 12,
			OnHoverChanged = setActionHovered,
			OnActivated = function()
				props.OnActivated(card)
			end,
		}),
	})
end)
