--!strict
-- Hover-only visual sample; existing effect inspection still opens the real effect scene.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local Icon = require(script.Parent.Icon)
local c = React.createElement
return function(props)
	local ref = React.useRef(nil)
	local sound = props.Category == "ElimEffectAssets"
	React.useEffect(function()
		local target = ref.current
		if not target or not props.Playing or GuiService.ReducedMotionEnabled then
			return nil
		end
		if not sound then
			return Motion.confettiBurst(target)
		end
		local tweens = {}
		for index = 1, 3 do
			local bar = target:FindFirstChild("Wave" .. index)
			if bar then
				local tween = TweenService:Create(
					bar,
					TweenInfo.new(0.18 + index * 0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Size = UDim2.fromScale(0.04, 0.25 + index * 0.09) }
				)
				table.insert(tweens, tween)
				tween:Play()
			end
		end
		return function()
			for _, tween in tweens do
				tween:Cancel()
			end
			for index = 1, 3 do
				local bar = target:FindFirstChild("Wave" .. index)
				if bar then
					bar.Size = UDim2.fromScale(0.04, 0.15)
				end
			end
		end
	end, { props.Playing })
	local children = {
		Blob = c("Frame", {
			BackgroundColor3 = if sound then T.Colors.Cyan else T.Colors.Grape,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.82),
			ZIndex = props.ZIndex,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Stroke = c("UIStroke", { Color = T.Colors.Ink, Thickness = T.Shape.StrokeCard }),
			Glyph = c(Icon, {
				Name = props.Definition.Icon or (if sound then "Speaker" else "Explosion"),
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.76, 0.76),
					ZIndex = props.ZIndex + 1,
				},
			}),
		}),
	}
	if sound then
		for index = 1, 3 do
			children["Wave" .. index] = c("Frame", {
				BackgroundColor3 = T.Colors.CyanLip,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.84 + index * 0.05, 0.5),
				Size = UDim2.fromScale(0.04, 0.15),
				Visible = props.Playing == true,
				ZIndex = props.ZIndex,
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
	end
	return c(
		"Frame",
		{ ref = ref, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = props.ZIndex },
		children
	)
end
