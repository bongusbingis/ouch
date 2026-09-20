--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Parent.Tokens)
local Summary = require(script.Parent.Parent.Parent.Models.CrateOddsSummary)
local Layout = require(script.Parent.Parent.Parent.Models.CrateOddsLayout)
local Selection = require(script.Parent.Parent.Parent.Services.Selection)
local number = require(script.Parent.Parent.Parent.Models.NumberText)
local Button = require(script.Parent.Parent.PuffyButton)
local Preview = require(script.Parent.ShopPreview)
local Ribbon = require(script.Parent.Parent.RarityRibbon)
local c, C = React.createElement, T.Colors
local function text(value, y, height, color, z)
	return c("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, height),
		Font = T.Type.Label,
		Text = value,
		TextSize = T.Type.Minimum,
		TextColor3 = color or C.Ink,
		TextWrapped = true,
		ZIndex = z,
	})
end
local function Tile(props)
	local entry = props.Entry
	local tier = T.Rarity[entry.rarity]
	local z = props.ZIndex
	local base = if entry.basePercent and entry.basePercent ~= entry.percent
		then " · BASE " .. tostring(entry.basePercent) .. "%"
		else ""
	return c(Button, {
		OnActivated = props.OnActivated,
		OnSelectionGained = function(button)
			Selection.scrollIntoView(button)
			local scroll = button:FindFirstAncestorWhichIsA("ScrollingFrame")
			if scroll then
				local position = scroll.CanvasPosition
				scroll.CanvasPosition = Vector2.new(
					position.X,
					Layout.reveal(
						button.AbsolutePosition.Y - scroll.AbsolutePosition.Y + position.Y,
						button.AbsoluteSize.Y,
						props.Inset,
						position.Y,
						scroll.AbsoluteWindowSize.Y,
						scroll.AbsoluteCanvasSize.Y
					)
				)
			end
		end,
		Style = "Card",
		Color = C.NeutralTile:Lerp(C.Surface, 0.4),
		Radius = T.Shape.RadiusCard,
		Shadow = false,
		StrokeColor = if props.Selected then C.Yellow else C.Ink,
		Native = { LayoutOrder = props.Order, Size = UDim2.fromOffset(props.Width, props.Height), ZIndex = z },
	}, {
		Chance = c(Ribbon, {
			Text = tostring(entry.percent) .. "%",
			Color = if tier then tier.Color else C.WellLine,
			Native = {
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.new(if entry.owned then 0.52 else 1, if entry.owned then -15 else -20, 0, 26),
				ZIndex = z + 6,
			},
		}),
		Owned = if entry.owned
			then c(Ribbon, {
				Text = "OWNED",
				Color = C.Yellow,
				Native = {
					Position = UDim2.new(0.52, 0, 0, 10),
					Size = UDim2.new(0.48, -10, 0, 26),
					ZIndex = z + 6,
				},
			})
			else nil,
		Preview = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 44),
			Size = UDim2.new(1, -16, 0, props.Height - 144),
			ZIndex = z + 6,
		}, {
			Content = c(Preview, {
				Items = if entry.preview then { entry.preview } else {},
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				ZIndex = z + 6,
			}),
		}),
		Name = c("TextLabel", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 1, -96),
			Size = UDim2.new(1, -16, 0, 52),
			Font = T.Type.Display,
			Text = string.upper(entry.displayName),
			TextSize = T.Type.Minimum,
			TextColor3 = C.Surface,
			TextWrapped = true,
			ZIndex = z + 7,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
			Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		}),
		Refund = text("DUPE: +" .. number(entry.bonksRefund or 0) .. " BONKS", props.Height - 42, 30, C.Ink, z + 7),
		Base = if base ~= "" then text("BASE " .. tostring(entry.basePercent) .. "%", 40, 24, C.Ink, z + 8) else nil,
	})
end
return function(props)
	local layout = props.Layout
	local columns, tileWidth, height = layout.columns, layout.tileWidth, layout.tileHeight
	local groups, byRarity = {}, {}
	for _, entry in props.Odds do
		local group = byRarity[entry.rarity]
		if not group then
			group = { rarity = entry.rarity, outcomes = {} }
			byRarity[entry.rarity] = group
			table.insert(groups, group)
		end
		table.insert(group.outcomes, entry)
	end
	local children = {}
	for index, group in groups do
		local chance, base, refund = Summary.shared(group.outcomes)
		local summary = if chance then tostring(chance) .. "% EACH" else "INDIVIDUAL CHANCES BELOW"
		if base and base ~= chance then
			summary ..= " · BASE " .. tostring(base) .. "%"
		end
		if refund then
			summary ..= " · DUPLICATES: " .. number(refund) .. " BONKS"
		end
		children["Header" .. group.rarity] = c("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index * 2 - 1,
			Size = UDim2.fromScale(1, 0),
			ZIndex = props.ZIndex,
		}, {
			Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
			Ribbon = c(Ribbon, {
				Rarity = group.rarity,
				Native = {
					LayoutOrder = 1,
					Size = UDim2.fromOffset(160, 30),
					ZIndex = props.ZIndex + 1,
				},
			}),
			Summary = c("TextLabel", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -8, 0, 26),
				Font = T.Type.Label,
				Text = summary,
				TextSize = T.Type.Minimum,
				TextColor3 = C.Ink,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				ZIndex = props.ZIndex + 1,
			}),
		})
		local tiles = {
			-- Include hover clearance in each group's canvas height, including the last row.
			Padding = c("UIPadding", {
				PaddingTop = UDim.new(0, layout.inset),
				PaddingBottom = UDim.new(0, layout.inset),
			}),
			Grid = c("UIGridLayout", {
				CellPadding = UDim2.fromOffset(layout.gap, layout.gap),
				CellSize = UDim2.fromOffset(tileWidth, height),
				FillDirectionMaxCells = columns,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for order, entry in group.outcomes do
			tiles[entry.itemId] = c(Tile, {
				Entry = entry,
				Order = order,
				Width = tileWidth,
				Height = height,
				Inset = layout.inset,
				Selected = props.SelectedId == entry.itemId,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				ZIndex = props.ZIndex,
				OnActivated = function()
					props.OnSelect(entry.itemId)
				end,
			})
		end
		children["Tiles" .. group.rarity] = c("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = index * 2,
			ZIndex = props.ZIndex,
		}, tiles)
	end
	return c(React.Fragment, nil, children)
end
