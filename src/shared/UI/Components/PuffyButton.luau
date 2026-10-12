--!strict
-- Stable AnimatedButton hitbox; all candy layers squash together inside its face.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local AnimatedButton = require(script.Parent.AnimatedButton)
local T = require(script.Parent.Parent.Tokens)
local c, C, S = React.createElement, T.Colors, T.Shape

local Surface = require(script.Parent.CandySurface)
local InputHint = require(script.Parent.InputHint)

return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Image = ""
	local children = table.clone(props.children or {})
	if props.Text and props.Hint then
		-- "[hint] LABEL": the hint sits left of the label and the pair stays centred;
		-- on touch the hint renders nothing and the label centres alone.
		children.Label = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -T.Layout.CompactGap, 1, -S.LipHeight),
			Position = UDim2.fromOffset(T.Layout.CompactGap / 2, 0),
			ZIndex = (native.ZIndex or 1) + 6,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, T.InputHint.Gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Hint = c(InputHint.Component, {
				Binding = props.Hint,
				Native = { LayoutOrder = 1, ZIndex = (native.ZIndex or 1) + 6 },
			}),
			Text = c("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0, 1),
				Font = T.Type.Display,
				Text = props.Text,
				TextSize = props.TextSize or T.Type.Tab,
				TextColor3 = props.TextColor or C.Surface,
				ZIndex = (native.ZIndex or 1) + 6,
			}, {
				Outline = if props.TextColor == C.Ink
					then nil
					else c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }),
			}),
		})
	elseif props.Text then
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
		FocusHint = props.FocusHint,
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
