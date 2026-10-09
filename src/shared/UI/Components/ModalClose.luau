--!strict
-- The candy close (X). Where Esc / B also closes the layer (the default), a
-- small keycap/glyph sticker on its lower-left corner says so; touch shows none.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Button = require(script.Parent.PuffyButton)
local InputHint = require(script.Parent.InputHint)
local BACK = require(RS:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input")).Hints.Back
return function(props)
	local side = props.SizePx or T.Layout.MinTarget
	local z = props.ZIndex or 4
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
			ZIndex = z,
		},
	}, {
		BackHint = if props.Hint ~= false
			then React.createElement(InputHint.Component, {
				Binding = BACK,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, T.InputHint.CornerInset, 1, -T.InputHint.CornerInset),
					ZIndex = z + 10,
				},
			})
			else nil,
	})
end
