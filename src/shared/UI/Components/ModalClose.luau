--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Button = require(script.Parent.PuffyButton)
return function(props)
	local side = props.SizePx or T.Layout.MinTarget
	return React.createElement(Button, {
		Text = "X",
		TextSize = T.Type.Tab,
		TextColor = T.Colors.Ink,
		Color = T.Colors.Surface,
		ButtonRef = props.ButtonRef,
		Enabled = props.Enabled ~= false and props.OnActivated ~= nil,
		OnActivated = props.OnActivated,
		Shadow = false,
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(1, 0),
			Position = props.Position or UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(side, side),
			ZIndex = props.ZIndex or 4,
		},
	})
end
