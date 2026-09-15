--!strict
-- Upright modal content and refs; only the cream silhouette carries the wonk.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c, C, S = React.createElement, T.Colors, T.Shape
return function(props)
	local native = table.clone(props.Native or props)
	for _, key in
		{ "children", "Native", "Color", "Radius", "Padding", "Gloss", "Shadow", "Tilt", "StrokeTransparency" }
	do
		native[key] = nil
	end
	for _, key in { "Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter", "SliceScale" } do
		native[key] = nil
	end
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Size = native.Size or UDim2.fromScale(1, 1)
	local z = native.ZIndex or 1
	local radius = props.Radius or S.RadiusPanel
	local corner = c("UICorner", { CornerRadius = UDim.new(0, radius) })
	local children = {}
	local content = table.clone(props.children or {})
	for key, child in content do
		local kind = if React.isValidElement(child) then child.type else nil
		if kind == "UIScale" or kind == "UISizeConstraint" or kind == "UIAspectRatioConstraint" then
			children[key] = child
			content[key] = nil
		end
	end
	local padding = props.Padding or 0
	if padding > 0 then
		content.Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
		})
	end
	children.Decoration = c(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = props.Tilt or S.TiltPanel, ZIndex = z },
		{
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
			Fill = c("Frame", {
				BackgroundColor3 = props.Color or C.SurfaceWarm,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z + 1,
			}, {
				Corner = corner,
				Outline = c(
					"UIStroke",
					{ Color = C.Ink, Thickness = if props.Shadow == false then S.StrokeCard else S.StrokePanel }
				),
			}),
		}
	)
	children.Face = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 2 }, content)
	return c("Frame", native, children)
end
