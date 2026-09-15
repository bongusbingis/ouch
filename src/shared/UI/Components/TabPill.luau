--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local PuffyButton = require(script.Parent.PuffyButton)
local T = require(script.Parent.Parent.Tokens)
return function(props)
	local native = table.clone(props.Native or {})
	native.Rotation = if props.Tilt ~= nil
		then props.Tilt
		else if (native.LayoutOrder or 1) % 2 == 0 then T.Shape.TiltTab else -T.Shape.TiltTab
	return React.createElement(PuffyButton, {
		Native = native,
		Text = props.Text,
		TextSize = props.TextSize,
		Color = if props.Active then T.Colors.Pink else T.Colors.Surface,
		LipColor = if props.Active then T.Colors.PinkLip else T.Colors.WellLine,
		TextColor = if props.Active then T.Colors.Surface else T.Colors.Ink,
		OnActivated = props.OnActivated,
		OnSelectionGained = props.OnSelectionGained,
		Enabled = props.Enabled,
		Shadow = props.Shadow,
		Style = props.Style,
		EntranceDelay = if props.Active then 0 else nil,
	})
end
