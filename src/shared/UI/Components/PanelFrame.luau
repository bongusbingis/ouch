--!strict
-- Tilt only decoration. The live scrolling well remains upright and clips correctly.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local c, C, S = React.createElement, T.Colors, T.Shape
return function(props)
	local ref = React.useRef(nil)
	React.useEffect(function()
		if ref.current then
			return Motion.popIn(ref.current)
		end
		return nil
	end, {})
	React.useEffect(function()
		local cleanup = nil
		local disconnect = Motion.onCelebrate(function()
			if cleanup then
				cleanup()
			end
			if ref.current then
				cleanup = Motion.confettiBurst(ref.current)
			end
		end)
		return function()
			disconnect()
			if cleanup then
				cleanup()
			end
		end
	end, {})
	local native = table.clone(props.Native or {})
	native.ref = ref
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	local children = table.clone(props.children or {})
	children.Decoration = c(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = props.Tilt or S.TiltPanel },
		{
			Shadow = c("Frame", {
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = S.ShadowTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(S.ShadowOffset.X, S.ShadowOffset.Y),
				Size = UDim2.fromScale(1, 1),
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusPanel) }) }),
			Face = c(
				"Frame",
				{ BackgroundColor3 = C.SurfaceWarm, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 },
				{
					Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusPanel) }),
					Outline = c("UIStroke", { Color = C.Ink, Thickness = S.StrokePanel }),
				}
			),
		}
	)
	return c("Frame", native, children)
end
