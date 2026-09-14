--!strict
-- Named rarity from the same palette as Backpack; callers may label product types.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c = React.createElement
return function(props)
	local tier = T.Rarity[props.Rarity]
	local native = table.clone(props.Native or {})
	native.BackgroundColor3 = props.Color or (if tier then tier.Color else T.Colors.WellLine)
	native.BorderSizePixel = 0
	native.Font = T.Type.Label
	native.Text = string.upper(props.Text or props.Rarity or "")
	native.TextColor3 = T.Colors.Ink
	native.TextSize = props.TextSize or T.Type.Minimum
	native.Size = native.Size or UDim2.fromOffset(T.Layout.RibbonWidth, T.Layout.RarityHeight)
	native.ZIndex = native.ZIndex or 8
	return c("TextLabel", native, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
		Outline = c(
			"UIStroke",
			{ Color = T.Colors.Ink, Thickness = T.Shape.StrokeInner, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
		),
		Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end
