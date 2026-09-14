--!strict
-- A recessed pill track with an inset raised fill; zero progress stays empty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local UI = require(ReplicatedStorage.Config.Interface.UI)
local c = React.createElement

return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundColor3 = props.TrackColor or UI.ProgressionStyle.Track
	native.BorderSizePixel = 0
	local fraction = math.clamp(props.Progress or 0, 0, 1)
	local color = props.Color or UI.ProgressionStyle.Pink
	local pill = UDim.new(1, 0)
	return c("Frame", native, {
		Corner = c("UICorner", { CornerRadius = pill }),
		Outline = c("UIStroke", { Color = UI.ProgressionStyle.Ink, Transparency = 0.25, Thickness = 1 }),
		Groove = c("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(105, 105, 105)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(220, 220, 220)),
				ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
			}),
		}),
		Channel = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(1, 1),
			Size = UDim2.new(1, -2, 1, -2),
		}, {
			Fill = c("Frame", {
				Visible = fraction > 0,
				BackgroundColor3 = UI.ProgressionStyle.White,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(fraction, 1),
			}, {
				Corner = c("UICorner", { CornerRadius = pill }),
				Sheen = c("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, color:Lerp(UI.ProgressionStyle.White, 0.28)),
						ColorSequenceKeypoint.new(0.4, color),
						ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.22)),
					}),
				}),
			}),
		}),
	})
end
