--!strict
-- Tintable vector masks give the selected tab sloped shoulders and a rounded base.
-- Artwork source: assets/source/ui/lobby-navigation-selection.svg.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c, C, N = React.createElement, T.Colors, T.LobbyNavigation

local function layer(mask, inset, depth, color, transparency, z, gradient)
	return c("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, depth),
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		Image = N.SelectionAtlas,
		ImageRectOffset = Vector2.new(mask * N.SelectionMaskSize.X, 0),
		ImageRectSize = N.SelectionMaskSize,
		ImageColor3 = color,
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = z,
	}, {
		Gradient = if gradient then c("UIGradient", gradient) else nil,
	})
end

return function(props)
	local compactScale = if props.Compact then 0.7 else 1
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Rotation = props.Rotation,
	}, {
		Shadow = layer(0, -T.Shape.StrokeInner, N.SelectionShadowDepth * compactScale, C.Ink, 0.65, 1),
		BaseEdge = layer(0, -T.Shape.StrokeInner, N.SelectionBaseDepth * compactScale, N.Rim, 0, 2),
		Base = layer(0, 0, N.SelectionBaseDepth * compactScale, N.Base, 0, 3),
		WhiteRim = layer(0, 0, 0, C.Surface, 0, 4, {
			Rotation = 90,
			Color = ColorSequence.new(C.Surface, N.SelectionRimBottom),
		}),
		PinkLip = layer(0, N.SelectionRimInset * compactScale, 0, C.PinkLip, 0, 5),
		Fill = layer(0, N.SelectionFillInset * compactScale, -N.SelectionFillLift, C.Surface, 0, 6, {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, N.SelectionTop),
				ColorSequenceKeypoint.new(0.48, C.Pink),
				ColorSequenceKeypoint.new(1, N.SelectionBottom),
			}),
		}),
		TopGloss = layer(1, N.SelectionRimInset * compactScale, -N.SelectionFillLift, C.Surface, 0.2, 7, {
			Rotation = 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(0.2, 0),
				NumberSequenceKeypoint.new(0.75, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
		BottomGloss = layer(2, N.SelectionRimInset * compactScale, 0, C.Surface, 0.5, 7),
	})
end
