--!strict
-- Reusable plastic skin; AnimatedButton supplies the press binding.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local UI = require(ReplicatedStorage.Config.Interface.UI)
local c = React.createElement

return function(props)
	local color = if props.Enabled ~= false
		then props.Color or UI.ProgressionStyle.Cyan
		else UI.ProgressionStyle.Disabled
	local corner = props.Radius or UDim.new(0, UI.Radius.Control)
	local depth = UI.Button.BevelPx
	local function pressed(map)
		return if props.PressDepth then props.PressDepth:map(map) else map(0)
	end
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = props.ZIndex or 0 }, {
		Shadow = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = UI.ProgressionStyle.Ink,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Position = pressed(function(value)
				return UDim2.new(0.5, 0, 0, depth + 3 - value * 4)
			end),
			Size = pressed(function(value)
				return UDim2.new(1, -value * 8, 1, -value * 2)
			end),
			ZIndex = 1,
		}, {
			Corner = c("UICorner", { CornerRadius = corner }),
			Fade = c("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.5, 0) }),
		}),
		Bevel = c("Frame", {
			BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), UI.Button.BevelDarken),
			BorderSizePixel = 0,
			Position = pressed(function(value)
				return UDim2.fromOffset(0, depth * (1 - value * 0.8))
			end),
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
			Outline = c(
				"UIStroke",
				{ Color = UI.ProgressionStyle.White, Thickness = UI.Button.StrokePx, Transparency = 0.12 }
			),
			Gloss = c("Frame", {
				BackgroundColor3 = UI.ProgressionStyle.White,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, {
				Corner = c("UICorner", { CornerRadius = corner }),
				Fade = c("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.76),
						NumberSequenceKeypoint.new(0.33, 1),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
		}),
	})
end
