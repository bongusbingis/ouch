-- Arena actions use the existing input, focus, motion and feedback primitive.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local Surface = require(script.Parent.Surface)
local Label = require(script.Parent.Label)
local c = React.createElement

return function(props)
	local enabled = props.Enabled ~= false
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Image = ""
	native.Size = native.Size or UDim2.fromOffset(200, Config.Action.HeightPx)
	native.ZIndex = native.ZIndex or 5
	return c(AnimatedButton, {
		SelectionRadius = UDim.new(0, Config.Surface.ControlRadiusPx),
		Native = native,
		Enabled = enabled,
		Style = if props.Primary then "Primary" else "Standard",
		OnActivated = props.OnActivated,
		ButtonRef = props.ButtonRef,
		Visual = c(Surface, {
			Radius = Config.Surface.ControlRadiusPx,
			Color = if props.Completed
				then Config.Colors.Claimed
				else if not enabled
					then Config.Colors.Disabled
					else props.Color or (if props.Primary then Config.Colors.Pink else Config.Colors.Cyan),
		}),
	}, {
		Minimum = c("UISizeConstraint", {
			MinSize = Vector2.new(Config.Action.MinimumPx, Config.Action.MinimumPx),
		}),
		Label = c(Label, {
			Text = props.Text,
			Title = true,
			Size = props.TextSize or Config.Action.TextPx,
			Color = Config.Colors.White,
			Native = {
				Position = UDim2.fromOffset(10, 2),
				Size = UDim2.new(1, -20, 1, -4),
				ZIndex = native.ZIndex + 1,
			},
		}),
	})
end
