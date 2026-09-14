--!strict
-- Shared fill/highlight/lip recipe for buttons, cards and passive stickers.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c, C, S = React.createElement, T.Colors, T.Shape
return function(props)
	local color = props.Color or C.Pink
	local radius = props.Radius or S.RadiusPill
	local lip = props.LipColor or color:Lerp(C.Ink, 0.22)
	local z = props.ZIndex or 1
	local corner = c("UICorner", { CornerRadius = UDim.new(0, radius) })
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z }, {
		Shadow = if props.Shadow ~= false
			then c("Frame", {
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = S.ShadowTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(S.ShadowOffset.X, S.ShadowOffset.Y),
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
			}, { Corner = corner })
			else nil,
		Lip = c(
			"Frame",
			{ BackgroundColor3 = lip, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z + 1 },
			{
				Corner = corner,
				Outline = c("UIStroke", {
					Color = props.StrokeColor or C.Ink,
					Thickness = S.StrokeTab,
					LineJoinMode = Enum.LineJoinMode.Round,
				}),
			}
		),
		Fill = c("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = if props.PressDepth
				then props.PressDepth:map(function(depth)
					return UDim2.new(1, 0, 1, -S.LipHeight * (1 - depth * 0.7))
				end)
				else UDim2.new(1, 0, 1, -S.LipHeight),
			ZIndex = z + 2,
		}, {
			Corner = corner,
			Highlight = c("Frame", {
				BackgroundColor3 = C.Surface,
				BackgroundTransparency = S.HighlightTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(S.StrokeTab, S.StrokeTab),
				Size = UDim2.new(1, -S.StrokeTab * 2, S.HighlightHeight, 0),
				ZIndex = z + 3,
			}, { Corner = corner, Fade = c("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }) }),
		}),
	})
end
