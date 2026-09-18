--!strict
-- One hero per card: a recessed art tile, one action pill, and stickers that overlap the edges.
local RS = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Parent.Tokens)
local ShopConfig = require(RS.Config.Economy.Shop)
local Style = require(script.Parent.Parent.Parent.Models.ShopCardStyle)
local Preview = require(script.Parent.ShopPreview)
local PriceButton = require(script.Parent.ShopPriceButton)
local ArtTile = require(script.Parent.ShopArtTile)
local Ribbon = require(script.Parent.Parent.RarityRibbon)
local Badge = require(script.Parent.Parent.Badge)
local Clipped = require(script.Parent.ScrollerClipped)
local Surface = require(script.Parent.Parent.CandySurface)
local Progress = require(script.Parent.Parent.CandyProgressBar)
local UIFeedback = require(script.Parent.Parent.Parent.Services.UIFeedback)
local c, C, L, S = React.createElement, T.Colors, T.Shop, T.Shape

local function labelWidth(text: string, textSize: number, padding: number): number
	return math.ceil(TextService:GetTextSize(text, textSize, T.Type.Label, Vector2.new(4096, 200)).X) + padding
end

return React.memo(function(props)
	local card = props.Card
	local pointerHovered, setPointerHovered = React.useState(false)
	local actionHovered, setActionHovered = React.useState(false)
	local hovered = pointerHovered or actionHovered
	local width, height = props.CardWidth, props.CardHeight
	local short = height <= T.LobbyLandscape.CardHeight
	local style = Style.resolve(card, props.SeasonState, {
		Headline = props.Headline == true,
		ShowProgress = height >= 220,
		RobuxSymbol = ShopConfig.RobuxSymbol,
	})
	local split = (props.Class.Layout == "Split" or style.season) and width >= L.PromoMin
	local pad = L.CardPadding
	local actionHeight = L.ActionHeight
	local actionY = height - pad - actionHeight
	local stickerHeight = if short then L.CompactStickerHeight else L.StickerHeight
	local stickerText = T.Type.Minimum
	local ribbonHeight = T.Layout.RarityHeight
	local ownedWidth = labelWidth(style.ownedText, stickerText, L.StickerPadding)
	local stickerWidth = if style.sticker then labelWidth(style.sticker.Text, stickerText, L.StickerPadding) else 0
	local stackedStamp = style.owned and style.sticker ~= nil and width < stickerWidth + ownedWidth + L.StickerPadding
	local ownedY = if stackedStamp then stickerHeight + 2 else -L.StickerOverhang

	local tileX, tileY = pad, pad
	local tileW, tileH, infoX, infoWidth
	if split then
		infoX = math.floor(width * L.SplitArtScale)
		tileW = infoX - pad - L.CopyGap
		tileH = height - pad * 2
		infoWidth = width - infoX - pad
	else
		infoX = pad
		infoWidth = width - pad * 2
		tileW = infoWidth
		tileH = actionY - pad - S.StrokeCard - tileY
		if style.progress ~= nil then
			tileH -= L.StackProgressReserve
		end
	end

	local tile = {}
	local artTop, artBottom
	if split then
		artTop, artBottom = 6, tileH - 6
	else
		local ribbonWidth = tileW
			- T.Layout.CompactGap * 2
			- (if style.owned then ownedWidth - T.Layout.CompactGap else 0)
		if style.rarity then
			tile.Rarity = c(Ribbon, {
				Rarity = style.rarity,
				Native = {
					Position = UDim2.fromOffset(T.Layout.CompactGap, S.StrokeCard),
					Size = UDim2.fromOffset(math.max(ribbonWidth, 60), ribbonHeight),
					ZIndex = 12,
				},
			})
		end
		artTop = if style.rarity then ribbonHeight + S.StrokeCard + 4 else S.StrokeCard + 4
		artBottom = tileH - L.BandHeight + S.StrokeCard - 6
		tile.Name = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, S.StrokeCard),
			Size = UDim2.new(1, -T.Layout.CompactGap, 0, L.BandHeight),
			Font = T.Type.Label,
			Text = style.name,
			TextSize = if width < 190 then T.Type.Minimum else T.Type.TileLabel,
			TextColor3 = C.Surface,
			TextWrapped = true,
			ZIndex = 12,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusPill) }),
			Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		})
	end
	tile.Artwork = c("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, artTop),
		Size = UDim2.fromOffset(math.max(tileW - 12, 1), math.max(artBottom - artTop, 28)),
		ZIndex = 10,
	}, {
		Content = c(Preview, {
			Items = style.previewItems,
			Playing = hovered,
			Thumbnail = card.thumbnail,
			Placeholder = card.badge,
			PlaceholderBonks = if style.currency then card.definition.BonksAmount else nil,
			ZIndex = 10,
		}),
	})

	local copy = {}
	if not split and style.progress ~= nil then
		copy.Progress = c(Progress, {
			Progress = style.progress,
			Color = C.Pink,
			Native = {
				Position = UDim2.fromOffset(infoX, actionY - 10 - 12),
				Size = UDim2.fromOffset(infoWidth, 12),
				ZIndex = 12,
			},
		})
	end
	if split then
		local nameSize = if short then T.Type.Minimum elseif props.Headline then T.Type.Tab else T.Type.TileLabel
		local top = pad + (if style.owned then stickerHeight - 6 else 0)
		local nameY = top + 2
		if style.rarity then
			copy.Kicker = c(Ribbon, {
				Rarity = style.rarity,
				Native = {
					Position = UDim2.fromOffset(infoX, top + 1),
					Size = UDim2.fromOffset(
						math.min(labelWidth(string.upper(style.rarity), T.Type.Minimum, 24), infoWidth),
						ribbonHeight
					),
					ZIndex = 12,
				},
			})
			nameY = top + 1 + ribbonHeight + 6
		end
		local nameHeight = if short then 40 else math.ceil(nameSize * 2.4)
		nameHeight = math.max(nameSize + 6, math.min(nameHeight, actionY - 6 - nameY))
		copy.Name = c("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(infoX, nameY),
			Size = UDim2.fromOffset(infoWidth, nameHeight),
			Font = T.Type.Display,
			Text = style.name,
			TextSize = nameSize,
			TextColor3 = C.Ink,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 12,
		})
		local cursor = nameY + nameHeight + 4
		if style.progress ~= nil then
			copy.Progress = c(Progress, {
				Progress = style.progress,
				Color = C.Pink,
				Native = {
					Position = UDim2.fromOffset(infoX, cursor + 2),
					Size = UDim2.fromOffset(infoWidth, 12),
					ZIndex = 12,
				},
			})
			cursor += 12 + 10
		end
		local secondaryHeight = actionY - 8 - cursor
		if style.secondary and not short and secondaryHeight >= T.Type.Minimum then
			copy.SupportingText = c("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(infoX, cursor),
				Size = UDim2.fromOffset(infoWidth, secondaryHeight),
				Font = T.Type.Label,
				Text = style.secondary,
				TextSize = T.Type.Minimum,
				TextColor3 = C.InkSoft,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 12,
			})
		end
	end

	local children = {
		Surface = c(Surface, {
			Color = style.bodyColor,
			Radius = S.RadiusCard,
			Shadow = false,
			StrokeColor = if hovered then C.Yellow else C.Ink,
			ZIndex = 4,
		}),
		Tile = c(ArtTile, {
			Color = style.tileColor,
			LineColor = style.tileLine,
			Position = UDim2.fromOffset(tileX, tileY),
			Size = UDim2.fromOffset(math.max(tileW, 1), math.max(tileH, 1)),
			ZIndex = 8,
		}, tile),
		-- The artwork/name affordance opens the same inspection as the footer.
		-- Keep sibling hitboxes separate and a single keyboard/controller stop.
		Inspect = c("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			Size = UDim2.new(1, 0, 0, actionY - S.StrokeCard * 2),
			ZIndex = 14,
			[React.Event.Activated] = function()
				UIFeedback.click()
				props.OnActivated(card)
			end,
		}),
		Action = c(PriceButton, {
			Text = style.action.Text,
			BonksAmount = style.action.BonksAmount,
			TextSize = if infoWidth < 220 then T.Type.Minimum else T.Type.TileLabel,
			Color = if style.primary then C.Pink else C.Surface,
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(infoX, actionY),
			Size = UDim2.fromOffset(infoWidth, actionHeight),
			ZIndex = 12,
			OnHoverChanged = setActionHovered,
			OnActivated = function()
				props.OnActivated(card)
			end,
		}),
		Sticker = if style.sticker
			then c(Clipped, {
				Native = {
					Position = UDim2.fromOffset(-L.StickerOverhang, -L.StickerOverhang),
					Size = UDim2.fromOffset(stickerWidth, stickerHeight),
					ZIndex = 15,
				},
			}, {
				Sticker = c(Badge, {
					Text = style.sticker.Text,
					Color = style.sticker.Color,
					TextColor = style.sticker.TextColor,
					TextSize = stickerText,
					Tilt = L.StickerTilt,
					Native = { Size = UDim2.fromScale(1, 1), ZIndex = 15 },
				}),
			})
			else nil,
		Owned = if style.owned
			then c(Clipped, {
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, L.StickerOverhang, 0, ownedY),
					Size = UDim2.fromOffset(ownedWidth, stickerHeight),
					ZIndex = 15,
				},
			}, {
				Stamp = c(Badge, {
					Text = style.ownedText,
					Color = C.Yellow,
					TextSize = stickerText,
					Native = { Size = UDim2.fromScale(1, 1), ZIndex = 15 },
				}),
			})
			else nil,
	}
	for key, child in copy do
		children[key] = child
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 1),
		ZIndex = 4,
		[React.Event.MouseEnter] = function()
			setPointerHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setPointerHovered(false)
		end,
	}, children)
end)
