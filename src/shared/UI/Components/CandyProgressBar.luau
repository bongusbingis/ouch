--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c = React.createElement
return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundColor3 = T.Colors.WellLine
	native.BorderSizePixel = 0
	local z = native.ZIndex or 1
	local stripe = { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }
	for i = 0, 40 do
		stripe["Stripe" .. i] = c("Frame", {
			BackgroundColor3 = T.Colors.Surface,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(i * T.Layout.StripeWidth * 2, -6),
			Size = UDim2.new(0, T.Layout.StripeWidth, 1, 12),
			Rotation = 0,
			ZIndex = z + 2,
		})
	end
	return c("Frame", native, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Outline = c("UIStroke", { Color = T.Colors.Ink, Thickness = T.Shape.StrokeInner }),
		Fill = c("Frame", {
			BackgroundColor3 = props.Color or T.Colors.Pink,
			BorderSizePixel = 0,
			Visible = (props.Progress or 0) > 0,
			ClipsDescendants = true,
			Size = UDim2.fromScale(math.clamp(props.Progress or 0, 0, 1), 1),
			ZIndex = z + 1,
		}, stripe),
	})
end
