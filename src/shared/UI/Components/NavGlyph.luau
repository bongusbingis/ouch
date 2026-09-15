--!strict
-- Chunky native glyphs, drawn here rather than importing another game's artwork.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c, C = React.createElement, T.Colors
local function shape(x, y, w, h, radius, color, rotation, outline)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BorderSizePixel = 0,
		BackgroundColor3 = color or C.Surface,
		Rotation = rotation or 0,
		ZIndex = 9,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) }),
		Stroke = if outline ~= false then c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeInner }) else nil,
	})
end
return function(props)
	local parts = {}
	if props.Id == "Shop" then
		parts.Basket = shape(0.52, 0.42, 0.65, 0.42, 5)
		parts.Handle = shape(0.16, 0.2, 0.35, 0.13, 4, nil, 50)
		parts.LeftWheel = shape(0.34, 0.85, 0.17, 0.17, 9)
		parts.RightWheel = shape(0.75, 0.85, 0.17, 0.17, 9)
	elseif props.Id == "Inventory" then
		parts.Handle = shape(0.5, 0.15, 0.4, 0.2, 5)
		parts.Bag = shape(0.5, 0.57, 0.68, 0.72, 7)
		parts.Pocket = shape(0.5, 0.7, 0.43, 0.26, 4, C.Pink)
	elseif props.Id == "Settings" then
		for i = 0, 7 do
			local a = i * math.pi / 4
			parts["Tooth" .. i] = shape(0.5 + math.sin(a) * 0.32, 0.5 + math.cos(a) * 0.32, 0.24, 0.32, 4, nil, -i * 45)
		end
		parts.Hub = shape(0.5, 0.5, 0.63, 0.63, 99, C.Surface, 0, false)
		parts.Hole = shape(0.5, 0.5, 0.23, 0.23, 99, C.Ink, 0, false)
	else
		parts.Play = c("TextLabel", {
			BackgroundTransparency = 1,
			Text = "▶",
			TextSize = 34,
			Font = Enum.Font.GothamBlack,
			TextColor3 = C.Surface,
			Position = UDim2.fromScale(0, -0.2),
			Size = UDim2.fromScale(1, 1.4),
			ZIndex = 9,
		}, { Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeInner }) })
	end
	return c("Frame", props.Native, parts)
end
