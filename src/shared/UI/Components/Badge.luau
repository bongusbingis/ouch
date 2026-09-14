--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local c = React.createElement
return function(props)
	local ref = React.useRef(nil)
	React.useEffect(function()
		if ref.current and props.Visible ~= false then
			return Motion.stampBadge(ref.current)
		end
		return nil
	end, { props.Text, props.Visible })
	local native = table.clone(props.Native or {})
	native.ref = ref
	native.BackgroundColor3 = props.Color or T.Colors.Yellow
	native.BorderSizePixel = 0
	native.Size = native.Size or UDim2.fromOffset(T.Layout.BadgeSize, T.Layout.BadgeSize)
	native.Rotation = T.Shape.TiltBadge
	native.Visible = props.Visible ~= false
	native.ZIndex = native.ZIndex or 12
	return c("Frame", native, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Outline = c("UIStroke", { Color = T.Colors.Ink, Thickness = T.Shape.StrokeCard }),
		Label = if not props.Lock
			then c("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = props.Text or "✓",
				TextSize = props.TextSize or T.Type.Section,
				Font = T.Type.Label,
				TextColor3 = T.Colors.Ink,
				ZIndex = native.ZIndex + 1,
			})
			else nil,
		Shackle = if props.Lock
			then c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.34, 0.22),
				Size = UDim2.fromScale(0.32, 0.38),
				ZIndex = native.ZIndex + 1,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Outline = c("UIStroke", { Color = T.Colors.Ink, Thickness = T.Shape.StrokeInner }),
			})
			else nil,
		LockBody = if props.Lock
			then c("Frame", {
				BackgroundColor3 = T.Colors.Ink,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.24, 0.45),
				Size = UDim2.fromScale(0.52, 0.34),
				ZIndex = native.ZIndex + 2,
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.StrokeInner) }) })
			else nil,
	})
end
