--!strict
local T = require(script.Parent.Parent.Tokens)
-- One reward browser presents the same tracks as a desktop grid or a landscape-phone strip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Colors = require(script.Parent.Parent.EconomyPalette)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local Layout = require(script.Parent.Parent.Models.SeasonLayout)
local Well = require(script.Parent.Well)
local S = T.SeasonRewards
local TabPill = require(script.Parent.TabPill)
local Ribbon = require(script.Parent.RarityRibbon)
local AnimatedButton = require(script.Parent.PuffyButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Model = require(script.Parent.Parent.Models.SeasonRewardsModel)
local Selection = require(script.Parent.Parent.Services.Selection)
local c = React.createElement

local function label(text, position, size, maximum, color, alignment, font)
	font = font or Enum.Font.FredokaOne
	return c(ResponsiveText, {
		MeasurementFont = font,
		MaxTextSize = math.max(T.Type.Minimum, maximum),
		MinTextSize = T.Type.Minimum,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = font,
			Text = text,
			TextWrapped = true,
			TextColor3 = if color == Colors.White or color == Colors.Yellow then T.Colors.Ink else color,
			TextXAlignment = alignment or Enum.TextXAlignment.Center,
			ZIndex = 107,
		},
	}, {
		Outline = if font == Enum.Font.FredokaOne
			then c("UIStroke", {
				Color = Colors.Ink,
				Thickness = 0,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			})
			else nil,
	})
end

return function(props)
	local compact = props.Compact == true
	local layout = Layout.browser(props.Width, compact)
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
				CellSize = UDim2.fromOffset(layout.cardWidth, S.CardHeight),
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
			TextSize = if compact then 18 else 22,
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
	for index, entry in props.Entries do
		if entry.track ~= track then
			continue
		end
		local definition = if entry.itemId then Cosmetics.Items[entry.itemId] else nil
		local chosen = entry.key == props.SelectedKey
		local status = if entry.claimed
			then "CLAIMED"
			else if entry.claimable
				then "READY TO CLAIM"
				else if entry.needsPremium then "PREMIUM REQUIRED" else "TIER LOCKED"
		local statusColor = if entry.claimed
			then T.Colors.NeutralTile
			else if entry.claimable then T.Colors.Yellow else T.Colors.Well
		local artLeft = if compact then 8 else S.CardInset
		cards[entry.key] = c(AnimatedButton, {
			Color = if chosen then T.Colors.SurfaceWarm else T.Colors.Surface,
			Shadow = false,
			Style = "Card",
			Radius = T.Shape.RadiusCard,
			StrokeColor = if chosen then T.Colors.Yellow else T.Colors.Ink,
			ButtonRef = if chosen then selectedRef else nil,
			OnSelectionGained = Selection.scrollIntoView,
			Native = {
				Size = if compact
					then UDim2.new(0, S.ShortCardWidth, 1, -S.ScrollPadding * 2)
					else UDim2.fromOffset(layout.cardWidth, S.CardHeight),
				LayoutOrder = index,
				ZIndex = 105,
			},
			OnActivated = function()
				props.OnSelectEntry(entry, true)
			end,
		}, {
			Limit = if compact
				then c("UISizeConstraint", { MaxSize = Vector2.new(S.ShortCardWidth, S.ShortCardMaxHeight) })
				else nil,
			Tier = label(
				`TIER {entry.tier}`,
				UDim2.fromOffset(if compact then 92 else S.CardInset, if compact then 4 else 8),
				UDim2.new(1, if compact then -102 else -S.CardInset * 2, 0, 24),
				18,
				T.Colors.InkSoft,
				Enum.TextXAlignment.Left,
				T.Type.Label
			),
			Art = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(artLeft, if compact then 6 else S.CardArtTop),
				Size = if compact then UDim2.new(0, 78, 1, -12) else UDim2.new(1, -S.CardInset * 2, 0, S.CardArtHeight),
				ZIndex = 106,
			}, {
				Content = if entry.kind == "Bonks"
					then c(BonksLabel, {
						Amount = entry.amount,
						MaxTextSize = if compact then 24 else 36,
						TextColor = T.Colors.Ink,
						TextStroke = 0,
						Native = { Size = UDim2.fromScale(1, 1), ZIndex = 107 },
					})
					else c(ShopPreview, {
						Items = if definition
							then { { itemId = entry.itemId, category = definition.Category, definition = definition } }
							else {},
						TextColor = T.Colors.Ink,
						TextStroke = 0,
						ZIndex = 106,
					}),
			}),
			Rarity = if definition and not compact
				then c(Ribbon, {
					Rarity = definition.Rarity,
					TextSize = T.Type.Minimum,
					Native = {
						Position = UDim2.fromOffset(S.CardInset, 128),
						Size = UDim2.new(1, -S.CardInset * 2, 0, 24),
						ZIndex = 108,
					},
				})
				else nil,
			NameBand = c("Frame", {
				BackgroundColor3 = T.Colors.Ink,
				BackgroundTransparency = if compact then 1 else 0,
				BorderSizePixel = 0,
				Position = if compact then UDim2.fromOffset(92, 27) else UDim2.fromOffset(S.CardInset, 160),
				Size = if compact
					then UDim2.new(1, -102, 1, -65)
					else UDim2.new(1, -S.CardInset * 2, 0, S.CardNameHeight),
				ZIndex = 106,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
				Name = c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MinTextSize = T.Type.Minimum,
					MaxTextSize = 20,
					Wrapped = true,
					Native = {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(6, 2),
						Size = UDim2.new(1, -12, 1, -4),
						Text = if definition then definition.DisplayName else "BONKS",
						Font = T.Type.Label,
						TextColor3 = if compact then T.Colors.Ink else T.Colors.Surface,
						TextWrapped = true,
						ZIndex = 107,
					},
				}),
			}),
			Status = c("Frame", {
				BackgroundColor3 = statusColor,
				BorderSizePixel = 0,
				Position = UDim2.new(0, if compact then 92 else S.CardInset, 1, -S.CardStatusHeight - 6),
				Size = UDim2.new(1, if compact then -102 else -S.CardInset * 2, 0, S.CardStatusHeight),
				ZIndex = 106,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Label = label(
					status,
					UDim2.fromOffset(4, 0),
					UDim2.new(1, -8, 1, 0),
					18,
					T.Colors.Ink,
					nil,
					T.Type.CompactLabel
				),
			}),
		})
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
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = T.Colors.Pink,
			ZIndex = 104,
		}, cards),
	})
end
