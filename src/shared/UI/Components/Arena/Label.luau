-- Arena typography shares responsive sizing and the game's existing fonts.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local c = React.createElement

return function(props)
	local title = props.Title == true
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Font = if title then Enum.Font.LuckiestGuy else UI.Text.BodyFont
	native.Text = props.Text or ""
	native.TextColor3 = props.Color or Config.Colors.White
	native.TextXAlignment = props.Align or Enum.TextXAlignment.Center
	native.ZIndex = native.ZIndex or 3
	native.Size = native.Size or UDim2.fromScale(1, 1)
	return c(ResponsiveText, {
		HostName = props.Name,
		MeasurementFont = native.Font,
		MinTextSize = props.Minimum or Config.Text.MinimumPx,
		MaxTextSize = props.Size or 24,
		Native = native,
	}, {
		Stroke = c("UIStroke", {
			Color = Config.Colors.Ink,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = if title then Config.Text.TitleStroke else Config.Text.BodyStroke,
		}),
	})
end
