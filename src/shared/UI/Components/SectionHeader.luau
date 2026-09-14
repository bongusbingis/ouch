-- Name: SectionHeader.luau
-- Author: Jack C.
-- Description: The one section heading used by the Backpack, Shop and Settings pages: display lettering with an ink stroke and a two-pixel underline that hugs the text, plus an optional right-aligned accessory such as a countdown or scroll hint.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)

local c = React.createElement
local Palette = UIConfig.ProgressionStyle
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local CandySectionHeader = require(script.Parent.CandySectionHeader)

export type Props = {
	Candy: boolean?,
	Text: string,
	TextSize: number?,
	HeightPx: number?,
	Color: Color3?,
	UnderlineGapPx: number?,
	Accessory: any?,
	AccessoryWidthPx: number?,
	LayoutOrder: number?,
	Position: UDim2?,
	Size: UDim2?,
	ZIndex: number?,
}

return function(props: Props)
	local preferred = usePreferredTextSize()
	local scale = UIConfig.Text.PreferredScale[preferred.Name] or 1
	if props.Candy then
		return c(CandySectionHeader, props)
	end
	local textSize = math.round((props.TextSize or UIConfig.Layout.SectionHeader.TextPx) * scale)
	local height = props.HeightPx or UIConfig.Layout.SectionHeader.HeightPx
	local gap = props.UnderlineGapPx or UIConfig.Layout.SectionHeader.UnderlineGapPx
	local z = props.ZIndex or 4
	local accessoryWidth = if props.Accessory then (props.AccessoryWidthPx or 120) + 8 else 0
	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.new(1, 0, 0, height),
		ZIndex = z,
	}, {
		Lettering = c("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, -UIConfig.Layout.SectionHeader.BottomGapPx),
			ZIndex = z,
		}, {
			Clamp = c("UISizeConstraint", { MaxSize = Vector2.new(math.max(1, 4096 - accessoryWidth), math.huge) }),
			Title = c("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Size = UDim2.new(0, 0, 1, -(gap + UIConfig.Layout.SectionHeader.UnderlinePx)),
				Text = props.Text,
				TextColor3 = props.Color or Palette.White,
				TextSize = textSize,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				ZIndex = z + 1,
			}, {
				Outline = c("UIStroke", {
					Color = Palette.Ink,
					Thickness = 0.045,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
			Underline = c("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = props.Color or Palette.White,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, UIConfig.Layout.SectionHeader.UnderlinePx),
				ZIndex = z + 1,
			}),
		}),
		Accessory = if props.Accessory
			then c("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(
					1,
					0,
					0.5,
					-(gap + UIConfig.Layout.SectionHeader.UnderlinePx + UIConfig.Layout.SectionHeader.BottomGapPx) / 2
				),
				Size = UDim2.fromOffset(props.AccessoryWidthPx or 120, height),
				ZIndex = z + 1,
			}, { Content = props.Accessory })
			else nil,
	})
end
