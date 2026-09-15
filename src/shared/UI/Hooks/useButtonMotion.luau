--!strict
-- One cancellable tween drives scale, rotation and bevel compression together.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.react)
local T = require(script.Parent.Parent.Tokens)

return function(scale: number, rotation: number, pressing: boolean, reducedMotion: boolean)
	local driver = React.useRef(nil)
	local value, update = React.useBinding(Vector3.new(1, 0, 0))
	React.useEffect(function()
		local source = Instance.new("Vector3Value")
		source.Value = Vector3.new(1, 0, 0)
		driver.current = source
		local connection = source.Changed:Connect(update)
		return function()
			connection:Disconnect()
			driver.current = nil
			source:Destroy()
		end
	end, {})
	React.useEffect(function()
		local source = driver.current
		if not source then
			return
		end
		local target = Vector3.new(scale, rotation, if pressing then 1 else 0)
		if reducedMotion then
			source.Value = target
			return
		end
		local tween = TweenService:Create(
			source,
			TweenInfo.new(
				if pressing then T.Motion.Press else T.Motion.Release,
				Enum.EasingStyle.Cubic,
				Enum.EasingDirection.Out
			),
			{ Value = target }
		)
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { scale, rotation, pressing, reducedMotion })
	return {
		Scale = value:map(function(v)
			return v.X
		end),
		Rotation = value:map(function(v)
			return v.Y
		end),
		PressDepth = value:map(function(v)
			return math.clamp(v.Z, 0, 1)
		end),
	}
end
