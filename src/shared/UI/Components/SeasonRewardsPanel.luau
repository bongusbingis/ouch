-- One reward browser presents the same tracks as a desktop grid or a landscape-phone strip.
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Colors = UI.ProgressionStyle
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local PriceButton = require(script.Parent.Shop.ShopPriceButton)
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Model = require(script.Parent.Parent.Models.SeasonRewardsModel)
local Selection = require(script.Parent.Parent.Services.Selection)
local c = React.createElement

local function label(text, position, size, maximum, color, alignment, font)
	font = font or Enum.Font.LuckiestGuy
	return c(ResponsiveText, {
		MeasurementFont = font,
		MaxTextSize = maximum,
		MinTextSize = 12,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = font,
			Text = text,
			TextWrapped = true,
			TextColor3 = color,
			TextXAlignment = alignment or Enum.TextXAlignment.Center,
			ZIndex = 107,
		},
	}, {
		Outline = if color ~= Colors.Ink
			then c("UIStroke", {
				Color = Colors.Ink,
				Thickness = 0.045,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			})
			else nil,
	})
end

return function(props)
	local compact = props.Compact
	local width = props.Width
	local columns = math.clamp(math.floor((width + 10) / 164), 1, 4)
	local cardWidth = math.floor((width - 14 - (columns - 1) * 10) / columns)
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
					CellSize = UDim2.fromOffset(cardWidth, 176),
					CellPadding = UDim2.fromOffset(10, 10),
					FillDirectionMaxCells = columns,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }),
		}
	for index, name in { "Free", "Premium" } do
		tabs[name] = c(PriceButton, {
			Text = string.upper(name),
			TextSize = 18,
			Compact = true,
			Color = if track == name then Colors.Pink else Colors.Cyan,
			TextColor = if track == name then Colors.White else Colors.Ink,
			TextStroke = if track == name then 0.055 else 0,
			Position = UDim2.new((index - 0.5) / 2, 0, 0, 44),
			Size = UDim2.new(0.5, -8, 0, 44),
			ZIndex = 105,
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
			ButtonRef = if chosen then selectedRef else nil,
			OnSelectionGained = Selection.scrollIntoView,
			Native = {
				BackgroundColor3 = if entry.claimed then Colors.Claimed else Colors.White,
				BorderSizePixel = 0,
				Size = if compact then UDim2.new(0, 146, 1, -8) else UDim2.fromOffset(cardWidth, 176),
				LayoutOrder = index,
				ZIndex = 105,
			},
			OnActivated = function()
				props.OnSelectEntry(entry, true)
			end,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Outline = c("UIStroke", {
				Color = if chosen then Colors.Pink else if entry.claimable then Colors.Yellow else Colors.White,
				Thickness = if chosen then 3 else 2,
				Transparency = 0,
			}),
			Tier = label(
				`TIER {entry.tier}`,
				UDim2.fromOffset(9, 6),
				UDim2.new(0.48, -9, 0, 18),
				14,
				Colors.Ink,
				Enum.TextXAlignment.Left,
				UI.Text.BodyFont
			),
			Status = label(
				if entry.claimed then "CLAIMED" else if entry.claimable then "READY!" else "",
				UDim2.new(0.48, 0, 0, 6),
				UDim2.new(0.52, -9, 0, 18),
				12,
				Colors.Ink,
				Enum.TextXAlignment.Right,
				UI.Text.BodyFont
			),
			Art = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 28),
				Size = if compact
					then UDim2.new(
						if entry.kind == "Bonks" then 1 else 0,
						if entry.kind == "Bonks" then -12 else 44,
						1,
						-34
					)
					else UDim2.new(1, -12, 1, -74),
				ZIndex = 106,
			}, {
				Content = if entry.kind == "Bonks"
					then c(BonksLabel, {
						Amount = entry.amount,
						MaxTextSize = 34,
						TextColor = Colors.Ink,
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
						TextColor = Colors.Ink,
						TextStroke = 0,
						ZIndex = 106,
					}),
			}),
			NameBand = if compact and entry.kind == "Bonks"
				then nil
				else c("Frame", {
					BackgroundColor3 = if chosen
						then Colors.Pink
						else if entry.claimed then Colors.Claimed else Colors.Cyan,
					BorderSizePixel = 0,
					Position = if compact then UDim2.fromOffset(56, 28) else UDim2.new(0, 6, 1, -40),
					Size = if compact then UDim2.new(1, -62, 1, -34) else UDim2.new(1, -12, 0, 34),
					ZIndex = 106,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Name = label(
						if definition then definition.DisplayName else "BONKS",
						UDim2.fromOffset(5, 2),
						UDim2.new(1, -10, 1, -4),
						if compact then 15 else 17,
						if chosen then Colors.White else Colors.Ink
					),
				}),
		})
	end
	tabs.Cards = c("ScrollingFrame", {
		Selectable = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		AutomaticCanvasSize = if compact then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = if compact then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Colors.White,
		ZIndex = 104,
	}, cards)
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 104 }, tabs)
end
