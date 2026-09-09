-- Name: EmoteSlotRail.luau
-- Author: Jack C.
-- Description: The row of numbered wheel-slot chips above the Backpack emote grid: tap a chip to choose where the next emote goes, see what each slot holds, and reach the slot-count pass through the locked chips.
-- Created: 2026-09-09
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local EmoteWheelController = require(script.Parent.Parent.Services.EmoteWheelController)
local Config = ReplicatedStorage:WaitForChild("Config")
local UI = require(Config:WaitForChild("Interface"):WaitForChild("UI"))
local Emotes = require(Config:WaitForChild("Cosmetics"):WaitForChild("Emotes"))

local c = React.createElement
local Palette = UI.ProgressionStyle
local WHITE = Color3.new(1, 1, 1)
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

export type Props = {
	LayoutOrder: number,
	Compact: boolean,
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
	OnActivated: () -> (),
})
	local clip = if props.EmoteId then Emotes.Clips[props.EmoteId] else nil
	local label = if props.Locked then "SHOWTIME" elseif clip then string.upper(clip.DisplayName) else "EMPTY"
	local fill = if props.Locked then Palette.Disabled elseif clip then Palette.Cyan else Palette.Surface
	local ink = if props.Locked then Palette.Muted elseif clip then WHITE else Palette.Muted
	local height = if props.Compact then 40 else UI.Interaction.MinTargetPx
	return c(AnimatedButton, {
		Style = "Standard",
		Native = {
			BackgroundColor3 = fill,
			BackgroundTransparency = if clip or props.Locked then 0 else 0.35,
			BorderSizePixel = 0,
			LayoutOrder = props.Index,
			Size = UDim2.new(0.235, 0, 0, height),
		},
		SelectionRadius = UDim.new(0, 10),
		OnActivated = props.OnActivated,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Outline = c("UIStroke", {
			Color = if props.Selected then Palette.Yellow else WHITE,
			Thickness = if props.Selected then UI.Interaction.FocusStrokePx else UI.Button.StrokePx,
			Transparency = if props.Selected then 0 elseif clip then 0.15 else 0.55,
		}),
		Number = c("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = if props.Locked then Palette.Surface else Palette.Ink,
			BackgroundTransparency = if props.Locked then 0.4 else 0.15,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(height - 14, height - 14),
			ZIndex = 3,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Text = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Size = UDim2.fromScale(1, 1),
				Text = tostring(props.Index),
				TextColor3 = if props.Selected then Palette.Yellow else WHITE,
				TextSize = math.max(height - 26, 12),
				ZIndex = 4,
			}),
		}),
		Label = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = if props.Compact then 12 else 13,
			MinTextSize = 10,
			Wrapped = true,
			Truncate = true,
			Native = {
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromOffset(height - 2, 0),
				Size = UDim2.new(1, -(height + 2), 1, 0),
				Text = label,
				TextColor3 = ink,
				TextTransparency = if clip or props.Locked then 0 else 0.25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 3,
			},
		}, {
			Outline = c("UIStroke", {
				Color = Palette.Ink,
				Thickness = if clip then 1.2 else 0,
				Transparency = 0.35,
			}),
		}),
	})
end

return function(props: Props)
	local wheel = EmoteWheelController.useSnapshot()
	local chips = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0.02, 0),
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
	local subtitle = if props.SelectedSlot
		then `TAP AN EMOTE FOR SLOT {props.SelectedSlot}`
		elseif wheel.capacity < Emotes.MaxSlots then "TAP AN EMOTE TO FILL A SLOT. SHOWTIME UNLOCKS 5-8"
		else "TAP AN EMOTE TO FILL A SLOT. TAP AGAIN TO REMOVE"
	return c(React.Fragment, nil, {
		Header = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(1, 0, 0, props.HeaderHeight),
		}, {
			Frame = c("Frame", {
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -4),
				Size = UDim2.new(1, 0, 0, 3),
				ZIndex = 4,
			}),
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 32,
				Truncate = true,
				Native = {
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Size = UDim2.new(0.5, 0, 1, -8),
					Text = "YOUR WHEEL",
					TextColor3 = WHITE,
					TextStrokeColor3 = Palette.Ink,
					TextStrokeTransparency = 0.15,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
			Subtitle = c(ResponsiveText, {
				HostName = "Subtitle",
				MeasurementFont = UI.Text.BodyFont,
				MaxTextSize = 14,
				MinTextSize = 10,
				Truncate = true,
				Native = {
					AnchorPoint = Vector2.new(1, 1),
					BackgroundTransparency = 1,
					FontFace = UI.Text.DefaultFont,
					Position = UDim2.new(1, 0, 1, -10),
					Size = UDim2.new(0.5, 0, 0, 18),
					Text = subtitle,
					TextColor3 = Palette.Muted,
					TextXAlignment = Enum.TextXAlignment.Right,
				},
			}),
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
