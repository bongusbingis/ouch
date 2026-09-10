-- Flexible rounded surfaces keep their edge and shadow intact at every aspect ratio.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local c = React.createElement

return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Size = native.Size or UDim2.fromScale(1, 1)
	local radius = props.Radius or Config.Surface.RadiusPx
	local shadow = if props.Shadow == false then 0 else Config.Surface.ShadowPx
	local content = table.clone(props.children or {})
	content.Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) })
	content.Stroke = c("UIStroke", {
		Color = props.StrokeColor or Config.Colors.White,
		Thickness = Config.Surface.StrokePx,
		Transparency = props.StrokeTransparency or 0,
	})
	return c("Frame", native, {
		Shadow = if shadow > 0
			then c("Frame", {
				BackgroundColor3 = Config.Colors.Shadow,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(shadow, shadow),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) }),
				Stroke = c("UIStroke", { Color = Config.Colors.Shadow, Thickness = Config.Surface.StrokePx }),
			})
			else nil,
		Face = c("Frame", {
			BackgroundColor3 = props.Color or Config.Colors.Cyan,
			BackgroundTransparency = props.Transparency or 0,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, content),
	})
end
