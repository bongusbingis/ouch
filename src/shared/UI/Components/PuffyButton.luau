--!strict
-- Stable AnimatedButton hitbox; all candy layers squash together inside its face.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local AnimatedButton = require(script.Parent.AnimatedButton)
local T = require(script.Parent.Parent.Tokens)
local c, C, S = React.createElement, T.Colors, T.Shape

local Surface = require(script.Parent.CandySurface)

return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Image = ""
	local children = table.clone(props.children or {})
	if props.Text then
		children.Label = c("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -T.Layout.CompactGap, 1, -S.LipHeight),
			Position = UDim2.fromOffset(T.Layout.CompactGap / 2, 0),
			Font = T.Type.Display,
			Text = props.Text,
			TextSize = props.TextSize or T.Type.Tab,
			TextColor3 = props.TextColor or C.Surface,
			TextWrapped = props.Wrapped == true,
			ZIndex = (native.ZIndex or 1) + 6,
		}, {
			Outline = if props.TextColor == C.Ink
				then nil
				else c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }),
		})
	end
	return c(AnimatedButton, {
		Native = native,
		ButtonRef = props.ButtonRef,
		Enabled = props.Enabled,
		Style = props.Style,
		OnActivated = props.OnActivated,
		OnSelectionGained = props.OnSelectionGained,
		OnHoverChanged = props.OnHoverChanged,
		OnPointerDown = props.OnPointerDown,
		EntranceDelay = props.EntranceDelay,
		SelectionRadius = UDim.new(0, props.Radius or S.RadiusPill),
		Visual = c(Surface, {
			Color = if props.Enabled == false then C.WellLine else props.Color,
			LipColor = props.LipColor,
			Radius = props.Radius,
			StrokeColor = props.StrokeColor,
			ZIndex = native.ZIndex,
			Shadow = props.Shadow,
		}),
	}, children)
end
