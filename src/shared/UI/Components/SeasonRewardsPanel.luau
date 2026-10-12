--!strict
-- One reward browser presents the same tracks as a desktop grid or a landscape-phone strip.
-- Every tile is the shared collectible card: cream body, rarity-tinted art window with the
-- seam rarity tag, CAPS name on the body, and one Builder Sans state chip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local T = require(script.Parent.Parent.Tokens)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Layout = require(script.Parent.Parent.Models.SeasonLayout)
local FaceLayout = require(script.Parent.Parent.Models.CollectibleLayout)
local formatNumber = require(script.Parent.Parent.Models.NumberText)
local Well = require(script.Parent.Well)
local TabPill = require(script.Parent.TabPill)
local Ribbon = require(script.Parent.RarityRibbon)
local CollectibleFace = require(script.Parent.CollectibleFace)
local AnimatedButton = require(script.Parent.PuffyButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Model = require(script.Parent.Parent.Models.SeasonRewardsModel)
local Selection = require(script.Parent.Parent.Services.Selection)
local c, C, S, K = React.createElement, T.Colors, T.SeasonRewards, T.Collectible

-- The Bonks coin on its own (the glyph BonksLabel draws beside amounts): a
-- currency tile names its amount once, on the card body, so the window holds
-- only the coin.
local BONKS_GLYPH = "rbxassetid://106703644238993"

-- One chip per tile says where the reward stands; the long wording is used
-- whenever the card is wide enough to hold it.
local function stateChip(entry, maxWidth: number): (string, Color3)
	local long, short, color
	if entry.claimed then
		long, short, color = "CLAIMED", "CLAIMED", C.Lime
	elseif entry.claimable then
		long, short, color = "READY TO CLAIM", "READY", C.Yellow
	elseif entry.needsPremium then
		long, short, color = "PREMIUM PASS", "PREMIUM", C.Gold
	else
		long, short, color = "TIER LOCKED", "LOCKED", C.Well
	end
	local text = if FaceLayout.tagWidth(long, T.Type.Minimum) <= maxWidth then long else short
	return text, color
end

local function chip(entry, maxWidth: number, native)
	local text, color = stateChip(entry, maxWidth)
	native.Size = UDim2.fromOffset(FaceLayout.tagWidth(text, T.Type.Minimum, maxWidth), K.TagHeight)
	return c(Ribbon, { Text = text, Color = color, Native = native })
end

local function art(entry, definition, z: number)
	if entry.kind == "Bonks" then
		return c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = BONKS_GLYPH,
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.86, 0.86),
			ZIndex = z,
		})
	end
	return c(ShopPreview, {
		Items = if definition
			then { { itemId = entry.itemId, category = definition.Category, definition = definition } }
			else {},
		TextColor = C.Ink,
		TextStroke = 0,
		ZIndex = z,
	})
end

local function rewardName(entry, definition): string
	if definition then
		return definition.DisplayName
	end
	return `{formatNumber(entry.amount or 0)} BONKS`
end

return function(props)
	local compact = props.Compact == true
	local layout = Layout.browser(props.Width, compact)
	-- Grid cards grow by the collectible extra height so the seam tag and state chip
	-- do not cost art height; strip cards fill the strip up to their cap.
	local cardHeight = S.CardHeight + K.ExtraHeight
	local shortCardHeight = math.clamp(
		(props.Height or S.ShortCardMaxHeight + S.ScrollPadding * 2) - S.ScrollPadding * 2,
		T.Layout.MinTarget,
		S.ShortCardMaxHeight
	)
	local track, setTrack = React.useState(function()
		for _, entry in props.Entries do
			if entry.key == props.SelectedKey then
				return entry.track
			end
		end
		return "Free"
	end)
	local selectedRef = React.useRef(nil)
	React.useEffect(function()
		local active = true
		task.defer(function()
			if active and selectedRef.current then
				local button = selectedRef.current
				local scroller = button:FindFirstAncestorWhichIsA("ScrollingFrame")
				if compact or not scroller then
					Selection.scrollIntoView(button)
				else
					-- Start on the selected tier's row instead of slicing through the previous row.
					local top = button.AbsolutePosition.Y
						- scroller.AbsolutePosition.Y
						+ scroller.CanvasPosition.Y
						- S.ScrollPadding
					scroller.CanvasPosition = Vector2.new(
						0,
						math.clamp(top, 0, math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y))
					)
				end
			end
		end)
		return function()
			active = false
		end
	end, { track, props.SelectedKey, compact })
	local cards = {
		Layout = if compact
			then c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, S.CardGap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			else c("UIGridLayout", {
				CellSize = UDim2.fromOffset(layout.cardWidth, cardHeight),
				CellPadding = UDim2.fromOffset(S.CardGap, S.CardGap),
				FillDirectionMaxCells = layout.columns,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, S.ScrollPadding),
			PaddingRight = UDim.new(0, S.ScrollPadding),
			PaddingTop = UDim.new(0, S.ScrollPadding),
			PaddingBottom = UDim.new(0, S.ScrollPadding),
		}),
	}
	local tabs = {}
	for index, name in { "Free", "Premium" } do
		tabs[name] = c(TabPill, {
			Active = track == name,
			Text = string.upper(name),
			TextSize = if compact then T.Type.Minimum else T.Type.TileLabel,
			Tilt = 0,
			Shadow = false,
			Style = "Primary",
			Native = {
				Position = if compact
					then UDim2.fromOffset(0, (index - 1) * (layout.tabHeight + S.ShortGap))
					else UDim2.fromOffset((index - 1) * (layout.tabWidth + S.TabGap), 0),
				Size = UDim2.fromOffset(layout.tabWidth, layout.tabHeight),
				LayoutOrder = index,
				ZIndex = 105,
			},
			OnActivated = function()
				setTrack(name)
				local entries = {}
				for _, entry in props.Entries do
					if entry.track == name then
						table.insert(entries, entry)
					end
				end
				local entry = Model.selected(entries, props.SelectedKey)
				if name == "Premium" and entry and entry.needsPremium then
					for _, reward in entries do
						local item = if reward.itemId then Cosmetics.Items[reward.itemId] else nil
						if item and item.Category == "CostumeAssets" and not reward.claimed then
							entry = reward
							break
						end
					end
				end
				if entry then
					props.OnSelectEntry(entry, false)
				end
			end,
		})
	end
	-- Sibling cards share one name size so a long name never shrinks only its own card.
	local stripFace = shortCardHeight - T.Shape.LipHeight
	local stripColumn = S.ShortCardWidth - stripFace - K.Pad
	local stripNameHeight = math.max(1, stripFace - K.Pad * 2 - K.FooterHeight - K.TagHeight - K.NameGap * 2)
	local names = {}
	for _, entry in props.Entries do
		if entry.track == track then
			local definition = if entry.itemId then Cosmetics.Items[entry.itemId] else nil
			table.insert(names, string.upper(rewardName(entry, definition)))
		end
	end
	local nameSize = if compact
		then FaceLayout.nameStyle(names, stripColumn, stripNameHeight)
		else FaceLayout.nameStyle(names, layout.cardWidth - K.Pad * 2, K.NameHeight)
	for index, entry in props.Entries do
		if entry.track ~= track then
			continue
		end
		local definition = if entry.itemId then Cosmetics.Items[entry.itemId] else nil
		local chosen = entry.key == props.SelectedKey
		local name = rewardName(entry, definition)
		local face
		if compact then
			-- Strip card: a square art window on the left, then tier, name and state.
			local faceHeight = stripFace
			local column = stripFace
			local columnWidth = stripColumn
			face = {
				Face = c(CollectibleFace, {
					Width = column,
					Height = faceHeight,
					Rarity = if definition then definition.Rarity else nil,
					Art = art(entry, definition, 108),
					ZIndex = 106,
				}),
				Tier = c("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(column, K.Pad),
					Size = UDim2.fromOffset(columnWidth, K.FooterHeight),
					Font = T.Type.Label,
					Text = `TIER {entry.tier}`,
					TextSize = T.Type.Minimum,
					TextColor3 = C.InkSoft,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 107,
				}),
				ItemName = c("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(column, K.Pad + K.FooterHeight),
					Size = UDim2.fromOffset(columnWidth, stripNameHeight),
					Font = T.Type.Display,
					Text = string.upper(name),
					TextSize = nameSize,
					TextColor3 = C.Ink,
					TextWrapped = true,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 107,
				}),
				State = chip(entry, columnWidth, {
					Position = UDim2.fromOffset(column, faceHeight - K.Pad - K.TagHeight),
					ZIndex = 112,
				}),
			}
		else
			-- Grid card: tier chip in the window corner, seam rarity tag, CAPS name, state chip.
			local faceHeight = cardHeight - T.Shape.LipHeight
			local chipTop = faceHeight - K.Pad - K.TagHeight
			face = {
				Face = c(CollectibleFace, {
					Width = layout.cardWidth,
					Height = chipTop,
					Rarity = if definition then definition.Rarity else nil,
					CornerText = `TIER {entry.tier}`,
					CornerColor = C.Surface,
					Name = name,
					NameSize = nameSize,
					Art = art(entry, definition, 108),
					ZIndex = 106,
				}),
				State = chip(entry, layout.cardWidth - K.Pad * 2, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(layout.cardWidth / 2, chipTop),
					ZIndex = 112,
				}),
			}
		end
		cards[entry.key] = c(AnimatedButton, {
			Color = C.SurfaceWarm,
			Shadow = false,
			Style = "Card",
			Radius = T.Shape.RadiusCard,
			StrokeColor = if chosen then C.Yellow else C.Ink,
			ButtonRef = if chosen then selectedRef else nil,
			OnSelectionGained = Selection.scrollIntoView,
			Native = {
				Size = if compact
					then UDim2.fromOffset(S.ShortCardWidth, shortCardHeight)
					else UDim2.fromOffset(layout.cardWidth, cardHeight),
				LayoutOrder = index,
				ZIndex = 105,
			},
			OnActivated = function()
				props.OnSelectEntry(entry, true)
			end,
		}, face)
	end
	return c(Well, {
		Candy = true,
		Native = { BackgroundTransparency = if compact then 1 else 0, Size = UDim2.fromScale(1, 1), ZIndex = 103 },
	}, {
		Tabs = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(layout.inset, layout.inset),
			Size = UDim2.new(1, -layout.inset * 2, 0, layout.tabHeight),
			ZIndex = 105,
		}, tabs),
		Cards = c("ScrollingFrame", {
			Selectable = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(layout.cardsX, layout.cardsTop),
			Size = UDim2.new(1, -layout.cardsX - layout.inset, 1, -layout.cardsTop - layout.inset),
			AutomaticCanvasSize = if compact then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = if compact then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
			ScrollBarThickness = T.Layout.ScrollBar,
			ScrollBarImageColor3 = T.Colors.Pink,
			ZIndex = 104,
		}, cards),
	})
end
