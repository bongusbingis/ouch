-- Shared pill face preserves the same outline, corners and shadow at every button size.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local c = React.createElement

return function(props)
	local enabled = props.Enabled ~= false
	local color = if enabled then props.Color or UI.ProgressionStyle.Cyan else UI.ProgressionStyle.Disabled
	local corner = props.Radius or UDim.new(0, UI.Radius.Control)
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Shadow = c("Frame", {
			BackgroundColor3 = UI.ProgressionStyle.Shadow,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(UI.Button.ShadowPx, UI.Button.ShadowPx),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, { Corner = c("UICorner", { CornerRadius = corner }) }),
		Face = c("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			Corner = c("UICorner", { CornerRadius = corner }),
			Outline = c("UIStroke", {
				Color = if enabled then Color3.new(1, 1, 1) else UI.ProgressionStyle.Muted,
				Thickness = UI.Button.StrokePx,
			}),
		}),
	})
end
