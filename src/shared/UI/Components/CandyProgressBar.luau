--!strict
-- Plum-edged pink striped progress; Animated scrolls the stripes so a bar that
-- is waiting still reads as alive, and reduced motion holds them still.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local c = React.createElement
local function fraction(value: number): number
	return math.clamp(value, 0, 1)
end
return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundColor3 = T.Colors.WellLine
	native.BorderSizePixel = 0
	local z = native.ZIndex or 1
	local reducedMotion = useReducedMotion()
	local scrolling = props.Animated == true and not reducedMotion
	local offset, setOffset = React.useBinding(0)
	React.useEffect(function()
		if not scrolling then
			setOffset(0)
			return
		end
		local span = T.Layout.StripeWidth * 2
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed = (elapsed + deltaTime) % T.Motion.RingPeriod
			setOffset(-span * elapsed / T.Motion.RingPeriod)
		end)
		return function()
			connection:Disconnect()
		end
	end, { scrolling })
	local stripe = {}
	for i = 0, 41 do
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
	local progress: any = props.Progress or 0
	local bound = typeof(progress) ~= "number"
	return c("Frame", native, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Outline = c("UIStroke", { Color = T.Colors.Ink, Thickness = T.Shape.StrokeInner }),
		Fill = c("Frame", {
			BackgroundColor3 = props.Color or T.Colors.Pink,
			BorderSizePixel = 0,
			Visible = if bound
				then progress:map(function(value: number)
					return fraction(value) > 0
				end)
				else fraction(progress) > 0,
			ClipsDescendants = true,
			Size = if bound
				then progress:map(function(value: number)
					return UDim2.fromScale(fraction(value), 1)
				end)
				else UDim2.fromScale(fraction(progress), 1),
			ZIndex = z + 1,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stripes = c("Frame", {
				BackgroundTransparency = 1,
				Position = offset:map(function(value: number)
					return UDim2.fromOffset(value, 0)
				end),
				Size = UDim2.fromScale(1, 1),
				ZIndex = z + 2,
			}, stripe),
		}),
	})
end
