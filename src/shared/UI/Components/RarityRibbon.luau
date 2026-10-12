--!strict
-- The candy rarity tag: a small puffy chip (fill, darker lip, fading top
-- highlight, ink outline) naming an existing rarity, or an explicit product
-- label/colour. Callers size it to its label (CollectibleLayout.tagWidth) and
-- place it where no art can draw over it. Grape uses white outlined text, the
-- same rule as the grape stickers.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c, C, S, K = React.createElement, T.Colors, T.Shape, T.Collectible

return function(props)
	local tier = T.Rarity[props.Rarity]
	local color = props.Color or (if tier then tier.Color else C.WellLine)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Size = native.Size or UDim2.fromOffset(T.Layout.RibbonWidth, K.TagHeight)
	native.ZIndex = native.ZIndex or 8
	local z = native.ZIndex
	local light = color == C.Grape or color == C.Pink
	local corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusPill) })
	return c("Frame", native, {
		Lip = c("Frame", {
			BackgroundColor3 = color:Lerp(C.Ink, 0.22),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
		}, {
			Corner = corner,
			Outline = c("UIStroke", {
				Color = C.Ink,
				Thickness = S.StrokeInner,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Fill = c("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -K.TagLip),
			ZIndex = z + 1,
		}, {
			Corner = corner,
			Highlight = c("Frame", {
				BackgroundColor3 = C.Surface,
				BackgroundTransparency = S.HighlightTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(S.StrokeInner + 2, 2),
				Size = UDim2.new(1, -(S.StrokeInner + 2) * 2, S.HighlightHeight, 0),
				ZIndex = z + 2,
			}, { Corner = corner, Fade = c("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }) }),
		}),
		Label = c("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -K.TagLip),
			Font = T.Type.Label,
			Text = string.upper(props.Text or props.Rarity or ""),
			TextColor3 = if light then C.Surface else C.Ink,
			TextSize = props.TextSize or T.Type.Minimum,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = z + 3,
		}, {
			Padding = c("UIPadding", {
				PaddingLeft = UDim.new(0, K.TagPadding - 2),
				PaddingRight = UDim.new(0, K.TagPadding - 2),
			}),
			Outline = if light then c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline - 1 }) else nil,
		}),
	})
end
