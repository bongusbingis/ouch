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
local Face = require(script.Parent.Parent.CollectibleFace)
local CollectibleLayout = require(script.Parent.Parent.Parent.Models.CollectibleLayout)
local c, C = React.createElement, T.Colors
local function Tile(props)
	local entry = props.Entry
	local z = props.ZIndex
	-- The group header states whatever every outcome shares (chance, base chance,
	-- duplicate refund), so a tile only adds what is particular to it.
	local parts = {}
	if not props.SharedBase and entry.basePercent and entry.basePercent ~= entry.percent then
		table.insert(parts, "BASE " .. tostring(entry.basePercent) .. "%")
	end
	if not props.SharedRefund then
		table.insert(parts, "DUPE +" .. number(entry.bonksRefund or 0))
	end
	local footer = if #parts > 0 then table.concat(parts, " · ") else nil
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
		Color = C.SurfaceWarm,
		Radius = T.Shape.RadiusCard,
		Shadow = false,
		StrokeColor = if props.Selected then C.Yellow else C.Ink,
		Native = { LayoutOrder = props.Order, Size = UDim2.fromOffset(props.Width, props.Height), ZIndex = z },
	}, {
		-- The group header names the tier; the seam tag carries this outcome's chance in the tier colour.
		Face = c(Face, {
			Width = props.Width,
			Height = props.Height - T.Shape.LipHeight,
			Rarity = entry.rarity,
			TagText = tostring(entry.percent) .. "%",
			CornerText = if entry.owned then "OWNED" else nil,
			Name = entry.displayName,
			Footer = footer,
			ZIndex = z + 6,
			Art = c(Preview, {
				Items = if entry.preview then { entry.preview } else {},
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				ZIndex = z + 7,
			}),
		}),
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
			summary ..= " · DUPE +" .. number(refund) .. " BONKS"
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
					Size = UDim2.fromOffset(
						CollectibleLayout.tagWidth(string.upper(group.rarity), T.Type.Minimum),
						T.Collectible.TagHeight
					),
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
				SharedBase = base ~= nil,
				SharedRefund = refund ~= nil,
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
