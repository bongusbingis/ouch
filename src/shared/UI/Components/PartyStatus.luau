-- Description: Compact party status line showing member count and the current queue state.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ActivityDots = require(script.Parent.ActivityDots)
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

export type Props = {
	Text: string,
	Active: boolean,
}

return function(props: Props)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, {
		ActivityDots = c(ActivityDots, {
			Active = props.Active,
			Native = {
				Position = UDim2.fromScale(0.945, 0.5),
				Size = UDim2.fromScale(0.09, 0.72),
			},
		}),
		PartyState = c(ResponsiveText, {
			HostName = "PartyState",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 42,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.465, 0.52),
				Size = UDim2.fromScale(0.87, 1),
				Text = props.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Color3.fromRGB(24, 41, 48),
				TextStrokeTransparency = 0.25,
			},
		}),
	})
end
