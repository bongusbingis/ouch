-- Name: CrateOddsGrid.luau
-- Author: Jack C.
-- Description: Crate odds presented as rarity-sectioned grids of Backpack-style reward tiles, each showing a live preview, its next-open chance and an OWNED tag, so every reward is visible without tapping through a list.
-- Created: 2026-09-09
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local formatNumber = require(script.Parent.Parent.Parent.Models.NumberText)
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local OuchButton = require(script.Parent.Parent.OuchButton)
local InventoryPreview = require(script.Parent.Parent.InventoryPreview)
local ResponsiveText = require(script.Parent.Parent.OuchText)

local c = React.createElement
local colors = UIConfig.ProgressionStyle
local WHITE = Color3.new(1, 1, 1)
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.fromEnum(UIConfig.Text.BodyFont)

export type Props = {
	Odds: { any },
	SelectedId: string?,
	OnSelect: (string) -> (),
	TilePx: number,
	Columns: number,
	GapPx: number,
	Short: boolean,
	ColorId: string?,
	CostumeId: string?,
	ZIndex: number,
}

local function tileName(outcome: any): string
	local name = string.gsub(outcome.displayName, "^Default%s+", "")
	local category = if outcome.preview then outcome.preview.category else nil
	local suffix = if category == "BallAssets" then " Ball" elseif category == "HammerAssets" then " Hammer" else nil
	if suffix ~= nil and string.sub(name, -#suffix) == suffix and #name > #suffix then
		name = string.sub(name, 1, #name - #suffix)
	end
	return string.upper(name)
end

local function Tile(props: {
	Outcome: any,
	Selected: boolean,
	TilePx: number,
	Short: boolean,
	ColorId: string?,
	CostumeId: string?,
	ZIndex: number,
	LayoutOrder: number,
	OnActivated: () -> (),
})
	local outcome = props.Outcome
	local z = props.ZIndex
	local bandPx = if props.Short then 32 else 36
	local rarityColor = InventoryConfig.RarityColors[outcome.rarity] or colors.Cyan
	local preview = outcome.preview
	return c(AnimatedButton, {
		SelectionRadius = UDim.new(0, UIConfig.Radius.Control),
		Visual = c(OuchButton, { Color = if props.Selected then colors.Pink else colors.Cyan, ZIndex = z }),
		Style = "Card",
		HoverRotation = false,
		Native = {
			BackgroundTransparency = 1,
			Image = "rbxassetid://123285423801571",
			LayoutOrder = props.LayoutOrder,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(107, 27, 126, 128),
			Size = UDim2.fromOffset(props.TilePx, if props.Short then 92 else props.TilePx + bandPx),
			ZIndex = z,
		},
		OnActivated = props.OnActivated,
	}, {
		Background = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Image = "rbxassetid://80477338860845",
			ImageColor3 = rarityColor,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -4, 1, -4),
			ZIndex = z - 1,
		}, {
			Texture = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://6794188517",
				ImageTransparency = 0.92,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
			}),
		}),
		Preview = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 1, -bandPx - 18),
			ZIndex = z + 1,
		}, {
			Content = if preview
				then c(InventoryPreview, {
					ItemId = preview.itemId,
					Category = preview.category,
					Definition = preview.definition,
					ColorId = props.ColorId,
					CostumeId = props.CostumeId,
					ZIndex = z + 1,
				})
				else nil,
		}),
		Chance = c("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = colors.Pink,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(0, 24),
			ZIndex = z + 3,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
			Text = c("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = BODY_FONT,
				Size = UDim2.fromScale(0, 1),
				Text = tostring(outcome.percent) .. "%",
				TextColor3 = colors.Yellow,
				TextSize = UIConfig.Text.CaptionMinPx,
				ZIndex = z + 4,
			}, {
				Outline = c("UIStroke", {
					Color = colors.Ink,
					Thickness = UIConfig.Text.OutlineScale,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
		}),
		Owned = if outcome.owned
			then c("Frame", {
				AnchorPoint = Vector2.new(1, if props.Short then 0 else 1),
				AutomaticSize = if props.Short then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
				BackgroundColor3 = colors.Yellow,
				BorderSizePixel = 0,
				Position = if props.Short then UDim2.new(1, -8, 0, 8) else UDim2.new(1, -8, 1, -bandPx - 12),
				Size = if props.Short then UDim2.fromOffset(24, 24) else UDim2.fromOffset(0, 22),
				ZIndex = z + 3,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Padding = if not props.Short
					then c("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) })
					else nil,
				Check = if props.Short
					then c("ImageLabel", {
						BackgroundTransparency = 1,
						Image = "rbxassetid://168702841",
						ImageColor3 = colors.Ink,
						Position = UDim2.fromOffset(4, 4),
						Size = UDim2.fromOffset(16, 16),
						ZIndex = z + 4,
					})
					else nil,
				Text = if not props.Short
					then c("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = BODY_FONT,
						Size = UDim2.fromScale(0, 1),
						Text = "OWNED",
						TextColor3 = WHITE,
						TextSize = UIConfig.Text.CaptionMinPx,
						ZIndex = z + 4,
					}, {
						Outline = c("UIStroke", {
							Color = colors.Ink,
							Thickness = UIConfig.Text.OutlineScale,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						}),
					})
					else nil,
			})
			else nil,
		NameBand = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = colors.Pink,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, bandPx),
			ZIndex = z + 2,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
			Outline = if props.Selected then c("UIStroke", { Color = colors.Yellow, Thickness = 2 }) else nil,
			ItemName = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 17,
				MinTextSize = 14,
				Wrapped = true,
				Truncate = true,
				Native = {
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromOffset(4, 4),
					Size = UDim2.new(1, -8, 1, -4),
					Text = tileName(outcome),
					TextColor3 = if props.Selected then colors.Yellow else WHITE,
					TextWrapped = true,
					ZIndex = z + 3,
				},
			}, {
				Outline = c("UIStroke", {
					Color = colors.Ink,
					Thickness = 0.045,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
		}),
	})
end

local function sectionSummary(first: any): string
	local chance = tostring(first.percent) .. "%"
	local base = if first.basePercent and first.basePercent ~= first.percent then ` (base {first.basePercent}%)` else ""
	return `{chance} each{base}  •  Duplicates: {formatNumber(first.bonksRefund or 0)} Bonks`
end

return function(props: Props)
	local sections = {}
	local order = 0
	local groups: { { rarity: string, outcomes: { any } } } = {}
	local byRarity: { [string]: { any } } = {}
	for _, outcome in props.Odds do
		local bucket = byRarity[outcome.rarity]
		if bucket == nil then
			bucket = {}
			byRarity[outcome.rarity] = bucket
			table.insert(groups, { rarity = outcome.rarity, outcomes = bucket })
		end
		table.insert(bucket, outcome)
	end
	for _, group in groups do
		local rarityColor = InventoryConfig.RarityColors[group.rarity] or colors.Cyan
		local tiles = {
			Grid = c("UIGridLayout", {
				CellPadding = UDim2.fromOffset(props.GapPx, props.GapPx),
				CellSize = UDim2.fromOffset(props.TilePx, if props.Short then 92 else props.TilePx + 36),
				FillDirectionMaxCells = props.Columns,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, outcome in group.outcomes do
			tiles[outcome.itemId] = c(Tile, {
				Outcome = outcome,
				Selected = props.SelectedId == outcome.itemId,
				TilePx = props.TilePx,
				Short = props.Short,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				ZIndex = props.ZIndex,
				LayoutOrder = index,
				OnActivated = function()
					props.OnSelect(outcome.itemId)
				end,
			})
		end
		order += 1
		sections["Header" .. group.rarity] = c("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			ZIndex = props.ZIndex,
		}, {
			Layout = c(
				"UIListLayout",
				{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, if props.Short then 0 else 2) }
			),
			Padding = if not props.Short
				then c("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) })
				else nil,
			Name = c("TextLabel", {
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Size = UDim2.new(1, 0, 0, if props.Short then 22 else 26),
				Text = string.upper(group.rarity),
				TextColor3 = colors.Yellow,
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = props.ZIndex + 1,
			}, {
				Outline = c("UIStroke", {
					Color = colors.Ink,
					Thickness = 0.045,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
			Summary = c("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				FontFace = BODY_FONT,
				Size = UDim2.new(1, -4, 0, 20),
				Text = sectionSummary(group.outcomes[1]),
				TextColor3 = WHITE,
				TextSize = 16,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = props.ZIndex + 1,
			}, {
				Outline = c("UIStroke", {
					Color = colors.Ink,
					Thickness = UIConfig.Text.OutlineScale,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
		})
		order += 1
		sections["Tiles" .. group.rarity] = c("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			ZIndex = props.ZIndex,
		}, tiles)
	end
	return c(React.Fragment, nil, sections)
end
