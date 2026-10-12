--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Parent.Tokens)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Font = props.Font or (if props.Title then T.Type.Display else T.Type.Label)
	native.Text = props.Text or ""
	native.TextColor3 = props.Color or T.Colors.Ink
	native.TextXAlignment = props.Align or Enum.TextXAlignment.Center
	native.ZIndex = native.ZIndex or 5
	native.Size = native.Size or UDim2.fromScale(1, 1)
	return React.createElement(ResponsiveText, {
		HostName = props.Name,
		MeasurementFont = native.Font,
		MinTextSize = props.Minimum or T.Type.HudMinimum,
		MaxTextSize = props.Size or 20,
		Wrapped = native.TextWrapped == true,
		Native = native,
	}, {
		Outline = if props.Outline
			then React.createElement("UIStroke", { Color = T.Colors.Ink, Thickness = T.Type.Outline })
			else nil,
	})
end
