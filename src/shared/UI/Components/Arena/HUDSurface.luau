--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Parent.Tokens)
local CandySurface = require(script.Parent.Parent.CandySurface)
local c = React.createElement

return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Size = native.Size or UDim2.fromScale(1, 1)
	local children = table.clone(props.children or {})
	children.Surface = c(CandySurface, {
		Color = props.Color or T.Colors.SurfaceWarm,
		LipColor = if props.Color == nil or props.Color == T.Colors.SurfaceWarm then T.Colors.WellLine else nil,
		Radius = props.Radius or T.Shape.RadiusCard,
		Shadow = props.Shadow == true,
		ZIndex = 0,
	})
	return c("Frame", native, children)
end
