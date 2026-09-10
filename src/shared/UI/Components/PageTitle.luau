-- Shared display lettering for page and modal headings.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local UI = require(ReplicatedStorage.Config.Interface.UI)
local ResponsiveText = require(script.Parent.ResponsiveText)
local c = React.createElement

return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Font = Enum.Font.LuckiestGuy
	native.Text = props.Text
	native.TextColor3 = UI.ProgressionStyle.White
	native.TextXAlignment = props.Alignment or Enum.TextXAlignment.Center
	native.ZIndex = native.ZIndex or 5
	return c(ResponsiveText, {
		HostName = "Title",
		MeasurementFont = Enum.Font.LuckiestGuy,
		MinTextSize = 18,
		MaxTextSize = props.TextSize or 42,
		Native = native,
	}, {
		Outline = c("UIStroke", {
			Color = UI.ProgressionStyle.Ink,
			Thickness = 0.045,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		}),
	})
end
