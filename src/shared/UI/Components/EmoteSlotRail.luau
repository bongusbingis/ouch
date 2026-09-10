-- Name: EmoteSlotRail.luau
-- Author: Jack C.
-- Description: The row of numbered wheel-slot chips above the Backpack emote grid: tap a chip to choose where the next emote goes, see what each slot holds, and reach the slot-count pass through the locked chips.
-- Created: 2026-09-09
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local SectionHeader = require(script.Parent.SectionHeader)
local EmoteWheelController = require(script.Parent.Parent.Services.EmoteWheelController)
local Config = ReplicatedStorage:WaitForChild("Config")
local UI = require(Config:WaitForChild("Interface"):WaitForChild("UI"))
local Emotes = require(Config:WaitForChild("Cosmetics"):WaitForChild("Emotes"))

local c = React.createElement
local Palette = UI.ProgressionStyle
local WHITE = Color3.new(1, 1, 1)

export type Props = {
	LayoutOrder: number,
	Compact: boolean,
	ContentWidth: number,
	HeaderHeight: number,
	SelectedSlot: number?,
	OnSelectSlot: (number?) -> (),
	OnLockedSlot: (() -> ())?,
}

local function Chip(props: {
	Index: number,
	EmoteId: string?,
	Locked: boolean,
	Selected: boolean,
	Compact: boolean,
	Width: UDim,
	Narrow: boolean,
	OnActivated: () -> (),
})
	local clip = if props.EmoteId then Emotes.Clips[props.EmoteId] else nil
	local label = if props.Locked then "Showtime" elseif clip then clip.DisplayName else "Empty"
	local fill = if props.Selected then Palette.Pink elseif props.Locked then Palette.Surface else Palette.Claimed
	local ink = if props.Locked then Palette.Muted else WHITE
	local height = UI.Interaction.MinTargetPx
	local numberSize = if props.Narrow then 22 else 30
	return c(AnimatedButton, {
		Style = "Standard",
		Native = {
			BackgroundColor3 = fill,
			BackgroundTransparency = if props.Locked then 0.35 else 0,
			BorderSizePixel = 0,
			LayoutOrder = props.Index,
			Size = UDim2.new(props.Width, UDim.new(0, height)),
		},
		SelectionRadius = UDim.new(0, 10),
		OnActivated = props.OnActivated,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, UI.Radius.Tile) }),
		Outline = c("UIStroke", {
			Color = if props.Selected then Palette.Yellow else WHITE,
			Thickness = if props.Selected then UI.Interaction.FocusStrokePx else UI.Button.StrokePx,
			Transparency = if props.Selected then 0 elseif clip then 0.2 else 0.6,
		}),
		Number = c("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Palette.Ink,
			BackgroundTransparency = if props.Locked then 0.5 else 0,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(numberSize, numberSize),
			ZIndex = 3,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Text = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSansBold,
				Size = UDim2.fromScale(1, 1),
				Text = tostring(props.Index),
				TextColor3 = if props.Selected then Palette.Yellow else WHITE,
				TextSize = if props.Narrow then 16 else 20,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 4,
			}),
		}),
		Label = c(ResponsiveText, {
			MeasurementFont = Enum.Font.BuilderSansBold,
			MaxTextSize = UI.Text.CaptionMinPx,
			MinTextSize = 14,
			Wrapped = true,
			Truncate = true,
			Native = {
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSansBold,
				Position = UDim2.fromOffset(numberSize + 12, 0),
				Size = UDim2.new(1, -(numberSize + 18), 1, 0),
				Text = label,
				TextColor3 = ink,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 3,
			},
		}),
	})
end

return function(props: Props)
	local wheel = EmoteWheelController.useSnapshot()
	local gap = UI.Layout.Inventory.CardGapPx
	local columns = if props.ContentWidth >= 4 * 120 + gap * 3
		then 4
		elseif props.ContentWidth >= 2 * 104 + gap then 2
		else 1
	local chipWidth = (props.ContentWidth - gap * (columns - 1)) / columns
	local narrow = props.ContentWidth < 360
	local subtitle = if props.SelectedSlot then "CHOOSE AN EMOTE" else ""
	local extraHeaderHeight = if narrow and props.SelectedSlot then 22 else 0
	local chips = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Wraps = true,
		}),
		UIPadding = c("UIPadding", { PaddingBottom = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }),
	}
	for index = 1, Emotes.MaxSlots do
		local locked = index > wheel.capacity
		chips["Slot" .. index] = c(Chip, {
			Index = index,
			EmoteId = if locked then nil else wheel.slots[index],
			Locked = locked,
			Selected = props.SelectedSlot == index,
			Compact = props.Compact,
			Width = UDim.new(1 / columns, -math.ceil(gap * (columns - 1) / columns)),
			Narrow = chipWidth < 120,
			OnActivated = function()
				if locked then
					if props.OnLockedSlot then
						props.OnLockedSlot()
					end
					return
				end
				props.OnSelectSlot(if props.SelectedSlot == index then nil else index)
			end,
		})
	end
	return c(React.Fragment, nil, {
		Header = c(SectionHeader, {
			Text = "YOUR WHEEL",
			HeightPx = props.HeaderHeight + extraHeaderHeight,
			LayoutOrder = props.LayoutOrder,
			Accessory = if subtitle ~= ""
				then c("TextLabel", {
					BackgroundTransparency = 1,
					Font = UI.Text.BodyFont,
					Size = UDim2.fromScale(1, 1),
					Text = subtitle,
					TextColor3 = Palette.Yellow,
					TextSize = UI.Text.CaptionMinPx,
					TextXAlignment = Enum.TextXAlignment.Right,
				}, {
					Outline = c("UIStroke", {
						Color = Palette.Ink,
						Thickness = 0.035,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					}),
				})
				else nil,
			AccessoryWidthPx = if narrow then 0 else 180,
		}),
		Content = c("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder + 1,
			Size = UDim2.fromScale(1, 0),
		}, chips),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder + 2,
			Size = UDim2.new(1, 0, 0, UI.Layout.Inventory.SpacerHeightPx),
		}),
	})
end
