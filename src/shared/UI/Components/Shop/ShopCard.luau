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
local CollectibleLayout = require(script.Parent.Parent.Parent.Models.CollectibleLayout)
local Badge = require(script.Parent.Parent.Badge)
local Clipped = require(script.Parent.ScrollerClipped)
local Surface = require(script.Parent.Parent.CandySurface)
local Progress = require(script.Parent.Parent.CandyProgressBar)
local UIFeedback = require(script.Parent.Parent.Parent.Services.UIFeedback)
local Icon = require(script.Parent.Parent.Icon)
local c, C, L, S = React.createElement, T.Colors, T.Shop, T.Shape

local function labelWidth(text: string, textSize: number, padding: number): number
	return math.ceil(TextService:GetTextSize(text, textSize, T.Type.Label, Vector2.new(4096, 200)).X) + padding
end

local function textHeight(text: string, textSize: number, font: Enum.Font, width: number): number
	return math.ceil(TextService:GetTextSize(text, textSize, font, Vector2.new(math.max(width, 1), 10000)).Y)
end

-- A soft silhouette of what is coming holds the art tile while a 3D preview or
-- thumbnail is still being built, so cards never pop in from an empty well.
local SILHOUETTES: { [string]: string } = {
	BallAssets = "Ball",
	HammerAssets = "Hammer",
	CostumeAssets = "Celebration",
	CharacterColor = "Celebration",
	EmoteAssets = "Celebration",
}

local function placeholderIcon(items: { any }, thumbnail: string?): string?
	local first = items[1]
	if first ~= nil then
		-- Effect seals are drawn immediately and need no stand-in.
		return SILHOUETTES[first.category]
	end
	return if thumbnail ~= nil and thumbnail ~= "" then "Star" else nil
end

local function useArtReady(artRef: any, key: string): boolean
	local ready, setReady = React.useState(false)
	React.useEffect(function()
		setReady(false)
		local root = artRef.current
		if root == nil then
			setReady(true)
			return nil
		end
		local connections = {}
		local function done()
			setReady(true)
		end
		local image = root:FindFirstChildWhichIsA("ImageLabel", true)
		local viewport = root:FindFirstChildWhichIsA("ViewportFrame", true)
		local world = if viewport then viewport:FindFirstChildWhichIsA("WorldModel") else nil
		if world ~= nil then
			if #world:GetChildren() > 0 then
				done()
			else
				table.insert(connections, world.ChildAdded:Connect(done))
			end
		elseif image ~= nil then
			if image.IsLoaded then
				done()
			else
				table.insert(connections, image:GetPropertyChangedSignal("IsLoaded"):Connect(done))
			end
		else
			done()
		end
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { key })
	return ready
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
		SectionTitle = props.SectionTitle,
	})
	local artRef = React.useRef(nil)
	local hero = style.previewItems[1]
	local artKey = (if hero then `{hero.category}:{hero.itemId}` else "") .. (card.thumbnail or "")
	local artReady = useArtReady(artRef, artKey)
	local silhouette = placeholderIcon(style.previewItems, card.thumbnail)
	local split = (props.Class.Layout == "Split" or style.season) and width >= L.PromoMin
	local pad = L.CardPadding
	local actionHeight = L.ActionHeight
	local actionY = height - pad - actionHeight
	local stickerHeight = if short then L.CompactStickerHeight else L.StickerHeight
	local stickerText = T.Type.Minimum
	local ribbonHeight = T.Layout.RarityHeight
	-- The owned stamp leads with the shared Check icon (never a Unicode tick).
	local checkSize = stickerText
	local ownedWidth = labelWidth(style.ownedText, stickerText, L.StickerPadding) + checkSize + 4
	local stickerWidth = if style.sticker then labelWidth(style.sticker.Text, stickerText, L.StickerPadding) else 0
	local stackedStamp = style.owned and style.sticker ~= nil and width < stickerWidth + ownedWidth + L.StickerPadding
	local ownedY = if stackedStamp then stickerHeight + 2 else -L.StickerOverhang

	local tileX, tileY = pad, pad
	local tileW, tileH, infoX, infoWidth
	-- Stacked cards use the collectible face order: art tile, rarity tag pinned
	-- on its lower seam, then the CAPS name in plum Fredoka on the cream body.
	local half = if style.rarity then math.ceil(ribbonHeight / 2) else 0
	local stackNameHeight = if short then T.Type.Minimum + 8 else L.BandHeight - S.StrokeCard
	if split then
		infoX = math.floor(width * L.SplitArtScale)
		tileW = infoX - pad - L.CopyGap
		tileH = height - pad * 2
		infoWidth = width - infoX - pad
	else
		infoX = pad
		infoWidth = width - pad * 2
		tileW = infoWidth
		tileH = actionY - 4 - stackNameHeight - half - tileY
		if style.progress ~= nil then
			tileH -= L.StackProgressReserve
		end
	end

	local tile = {}
	local stacked = {}
	local artTop, artBottom
	if split then
		artTop, artBottom = 6, tileH - 6
	else
		artTop = S.StrokeCard + 4
		artBottom = tileH - half - 6
		if style.rarity then
			stacked.Rarity = c(Ribbon, {
				Rarity = style.rarity,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(tileX + tileW / 2, tileY + tileH - half),
					Size = UDim2.fromOffset(
						CollectibleLayout.tagWidth(string.upper(style.rarity), T.Type.Minimum, tileW - 12),
						ribbonHeight
					),
					ZIndex = 13,
				},
			})
		end
		local nameTop = tileY + tileH + (if half > 0 then half + T.Collectible.NameGap else 4)
		stacked.Name = c("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(infoX, nameTop),
			Size = UDim2.fromOffset(infoWidth, math.max(T.Type.Minimum + 4, stackNameHeight)),
			Font = T.Type.Display,
			Text = style.name,
			TextSize = if width < 190 then T.Type.Minimum else T.Type.TileLabel,
			TextColor3 = C.Ink,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = true,
			ZIndex = 12,
		})
	end
	if silhouette and not artReady then
		tile.Placeholder = c(Icon, {
			Name = silhouette,
			Color = style.tileLine,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				ImageTransparency = 0.45,
				Position = UDim2.fromOffset(tileW / 2, (artTop + artBottom) / 2),
				Size = UDim2.fromOffset(
					math.floor(math.min(tileW, artBottom - artTop) * 0.46),
					math.floor(math.min(tileW, artBottom - artTop) * 0.46)
				),
				ZIndex = 9,
			},
		})
	end
	tile.Artwork = c("Frame", {
		ref = artRef,
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
	-- The action sits on the card's bottom line so siblings in a row align; only a
	-- currency pack, whose copy is one fixed line, centres name and price together.
	local actionTop = actionY
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
						CollectibleLayout.tagWidth(string.upper(style.rarity), T.Type.Minimum, infoWidth),
						ribbonHeight
					),
					ZIndex = 12,
				},
			})
			nameY = top + 1 + ribbonHeight + 6
		end
		local lineHeight = textHeight("A", nameSize, T.Type.Display, infoWidth)
		local nameHeight = if short
			then 40
			else math.min(textHeight(style.name, nameSize, T.Type.Display, infoWidth), lineHeight * 2)
		if style.currency and not short then
			nameHeight = lineHeight
			local stack = nameHeight + T.Layout.CompactGap + actionHeight
			nameY = math.max(pad, math.floor((height - S.LipHeight - stack) / 2))
			actionTop = nameY + nameHeight + T.Layout.CompactGap
		end
		nameHeight = math.max(nameSize + 6, math.min(nameHeight, actionTop - 6 - nameY))
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
		local cursor = nameY + nameHeight + 6
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
		local limit = actionTop - T.Layout.CompactGap
		local function copyLine(key: string, text: string, color: Color3)
			local line = textHeight("A", T.Type.Minimum, T.Type.Label, infoWidth)
			local lines = math.floor((limit - cursor) / line)
			if lines < 1 then
				return
			end
			local blockHeight = math.min(textHeight(text, T.Type.Minimum, T.Type.Label, infoWidth), lines * line)
			copy[key] = c("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(infoX, cursor),
				Size = UDim2.fromOffset(infoWidth, blockHeight),
				Font = T.Type.Label,
				Text = text,
				TextSize = T.Type.Minimum,
				TextColor3 = color,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 12,
			})
			cursor += blockHeight + 4
		end
		if style.secondary and not short then
			copyLine("SupportingText", style.secondary, C.InkSoft)
		end
		if style.description and not short then
			copyLine("Description", style.description, C.InkSoft)
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
			-- Selectable only when the footer is a muted status (not focusable) so the
			-- card still has exactly one controller/keyboard stop.
			Selectable = style.actionState == "Muted",
			Size = UDim2.new(1, 0, 0, actionTop - S.StrokeCard * 2),
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
			Muted = style.actionState == "Muted",
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(infoX, actionTop),
			Size = UDim2.fromOffset(infoWidth, actionHeight),
			ZIndex = 12,
			OnHoverChanged = setActionHovered,
			OnActivated = function()
				if style.actionState == "Retry" and props.OnRetry then
					props.OnRetry()
				else
					props.OnActivated(card)
				end
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
					Text = "",
					Color = C.Yellow,
					Native = { Size = UDim2.fromScale(1, 1), ZIndex = 15 },
				}),
				Check = c(Icon, {
					Name = "Check",
					Color = C.Ink,
					Native = {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, L.StickerPadding / 2, 0.5, 0),
						Size = UDim2.fromOffset(checkSize, checkSize),
						ZIndex = 17,
					},
				}),
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(1, -(L.StickerPadding / 2 + checkSize + 4), 1, 0),
					Font = T.Type.Label,
					Text = style.ownedText,
					TextSize = stickerText,
					TextColor3 = C.Ink,
					ZIndex = 17,
				}),
			})
			else nil,
	}
	for key, child in copy do
		children[key] = child
	end
	for key, child in stacked do
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
