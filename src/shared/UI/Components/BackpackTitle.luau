--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Icon = require(script.Parent.Icon)
local c, C = React.createElement, T.Colors
return function(props)
	local compact = props.Compact
	local height = if compact then T.Layout.CompactTitleHeight else T.Layout.TitleHeight
	local textSize = if compact then T.Type.Section else T.Type.Title
	local text = {
		BackgroundTransparency = 1,
		Font = T.Type.Display,
		Text = "BACKPACK",
		TextSize = textSize,
		TextColor3 = C.Surface,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
	}
	local shadow = table.clone(text)
	shadow.TextColor3 = C.Ink
	shadow.Position = UDim2.fromOffset(T.Type.ShadowOffset.X, T.Type.ShadowOffset.Y)
	shadow.ZIndex = 7
	return c("Frame", {
		BackgroundColor3 = C.Pink,
		BorderSizePixel = 0,
		AnchorPoint = if props.Landscape then Vector2.zero else Vector2.new(0.5, 0),
		Position = if props.Landscape
			then UDim2.fromOffset(16, 2)
			else UDim2.new(0.5, 0, 0, if compact then -T.Layout.CompactGap else T.Layout.TitleTop),
		Size = if props.Landscape then UDim2.fromOffset(210, 42) else UDim2.new(0.54, 0, 0, height),
		Rotation = if props.Landscape then 0 else T.Shape.TiltTitle,
		ZIndex = 7,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusPanel) }),
		Outline = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokePanel }),
		Shadow = c("TextLabel", shadow),
		Title = c("TextLabel", text, { Outline = c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }) }),
		Star = if not props.Landscape
			then c(Icon, {
				Name = "Star",
				Color = C.Yellow,
				Native = {
					Position = UDim2.new(1, -8, 0, -T.Layout.CompactGap),
					Size = UDim2.fromOffset(height * 0.7, height * 0.7),
					ZIndex = 10,
				},
			})
			else nil,
		Sparkle = if not props.Landscape
			then c(Icon, {
				Name = "Sparkle",
				Color = C.Cyan,
				Native = {
					Position = UDim2.new(0, -height * 0.6, 0.3, 0),
					Size = UDim2.fromOffset(height * 0.45, height * 0.45),
					ZIndex = 10,
				},
			})
			else nil,
	})
end
