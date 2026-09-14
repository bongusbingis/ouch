--!strict
local T = require(script.Parent.Parent.Tokens)
-- One reward browser presents the same tracks as a desktop grid or a landscape-phone strip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Colors = require(script.Parent.Parent.EconomyPalette)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local ResponsiveText = require(script.Parent.ResponsiveText)
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
	local compact = props.Compact
	local width = props.Width
	local columns = math.clamp(math.floor((width + 18) / 202), 1, 4)
	local cardWidth = math.floor((width - 14 - (columns - 1) * 18) / columns)
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
				Selection.scrollIntoView(selectedRef.current)
			end
		end)
		return function()
			active = false
		end
	end, { track, props.SelectedKey })
	local tabs, cards =
		{}, {
			Layout = if compact
				then c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				else c("UIGridLayout", {
					CellSize = UDim2.fromOffset(cardWidth, 248),
					CellPadding = UDim2.fromOffset(18, 18),
					FillDirectionMaxCells = columns,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }),
		}
	for index, name in { "Free", "Premium" } do
		tabs[name] = c(TabPill, {
			Active = track == name,
			Text = string.upper(name),
			TextSize = 18,
			Compact = true,
			Color = if track == name then Colors.Pink else T.Colors.Surface,
			TextColor = if track == name then T.Colors.Surface else T.Colors.Ink,
			TextStroke = 0,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new((index - 0.5) / 2, 0, 0, 44),
				Size = UDim2.new(0.5, -UI.Spacing.ControlGapPx, 0, 44),
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
		cards[entry.key] = c(AnimatedButton, {
			Color = T.Colors.Surface,
			Shadow = false,
			Radius = T.Shape.RadiusCard,
			StrokeColor = if chosen then T.Colors.Yellow else T.Colors.Ink,
			ButtonRef = if chosen then selectedRef else nil,
			OnSelectionGained = Selection.scrollIntoView,
			Native = {
				BackgroundColor3 = Colors.Claimed,
				BorderSizePixel = 0,
				Size = if compact then UDim2.new(0, 146, 1, -8) else UDim2.fromOffset(cardWidth, 248),
				LayoutOrder = index,
				ZIndex = 105,
			},
			OnActivated = function()
				props.OnSelectEntry(entry, true)
			end,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, UI.Radius.Tile) }),
			Outline = c("UIStroke", {
				Color = if chosen then Colors.Pink else if entry.claimable then Colors.Yellow else Colors.White,
				Thickness = 0,
				Transparency = if chosen or entry.claimable then 0 else 0.6,
			}),
			Tier = label(
				`TIER {entry.tier}`,
				UDim2.fromOffset(9, 6),
				UDim2.new(1, -18, 0, 24),
				14,
				Colors.White,
				Enum.TextXAlignment.Left,
				T.Type.Label
			),
			Status = label(
				if entry.claimed
					then "CLAIMED"
					else if entry.claimable
						then "READY!"
						else if entry.needsPremium then "PREMIUM REQUIRED" else "TIER LOCKED",
				UDim2.fromOffset(9, 30),
				UDim2.new(1, -18, 0, 24),
				12,
				if entry.claimable then Colors.Yellow else Colors.White,
				Enum.TextXAlignment.Left,
				T.Type.Label
			),
			Art = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 60),
				Size = if compact
					then UDim2.new(
						if entry.kind == "Bonks" then 1 else 0,
						if entry.kind == "Bonks" then -12 else 44,
						1,
						-34
					)
					else UDim2.new(1, -12, 1, -180),
				ZIndex = 106,
			}, {
				Content = if entry.kind == "Bonks"
					then c(BonksLabel, {
						Amount = entry.amount,
						MaxTextSize = 34,
						TextColor = T.Colors.Ink,
						TextStroke = 0,
						Native = { Size = UDim2.fromScale(1, 1), ZIndex = 107 },
					})
					else c(ShopPreview, {
						Items = if definition
							then {
								{ itemId = entry.itemId, category = definition.Category, definition = definition },
							}
							else {},
						PlaceholderBonks = if entry.kind == "Bonks" then entry.amount else nil,
						TextColor = T.Colors.Ink,
						TextStroke = 0,
						ZIndex = 106,
					}),
			}),
			Rarity = if definition and not compact
				then c(Ribbon, {
					Rarity = definition.Rarity,
					TextSize = T.Type.Minimum,
					Native = { Position = UDim2.new(0, 8, 1, -100), Size = UDim2.new(1, -16, 0, 26), ZIndex = 111 },
				})
				else nil,
			NameBand = if compact and entry.kind == "Bonks"
				then nil
				else c("Frame", {
					BackgroundColor3 = T.Colors.WellLine,
					BorderSizePixel = 0,
					Position = if compact then UDim2.fromOffset(56, 28) else UDim2.new(0, 6, 1, -66),
					Size = if compact then UDim2.new(1, -62, 1, -34) else UDim2.new(1, -12, 0, 60),
					ZIndex = 106,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, UI.Radius.Tile) }),
					Name = label(
						if definition then definition.DisplayName else "BONKS",
						UDim2.fromOffset(5, 2),
						UDim2.new(1, -10, 1, -4),
						T.Type.Minimum,
						Colors.White
					),
				}),
		})
	end
	tabs.Cards = c("ScrollingFrame", {
		Selectable = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		AutomaticCanvasSize = if compact then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = if compact then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Colors.Pink,
		ZIndex = 104,
	}, cards)
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 104 }, tabs)
end
