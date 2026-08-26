-- Name: SettingsPage.luau
-- Author: Jack C.
-- Description: The settings page, exposing the audio volume controls and other client preferences.
-- Created: 2026-08-24

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

export type Props = {
	Position: any?,
}

return function(props: Props)
	return c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://136021539696619",
		LayoutOrder = 5,
		Position = props.Position or UDim2.fromScale(-0.005, 0.127),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.602, 0.748),
		SliceCenter = Rect.new(224, 202, 770, 474),
		SliceScale = 0.06,
	}, {
		Title = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 62,
			Native = {
				BackgroundColor3 = Color3.fromRGB(63, 63, 63),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.291804, 0.0540634),
				Size = UDim2.fromScale(0.398251, 0.0898091),
				Text = "SETTINGS",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
			},
		}),
		Main = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			Position = UDim2.fromScale(0.5, 0.575),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.93, 0.78),
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
		}, {
			Icon = c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://2161586632",
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ImageTransparency = 0.12,
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(0.18, 0.29),
			}, {
				Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			}),
			Status = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 58,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.65),
					Size = UDim2.fromScale(0.72, 0.14),
					Text = "COMING SOON",
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 5,
				},
			}, {
				Stroke = c("UIStroke", {
					Color = Color3.fromRGB(63, 63, 63),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.045,
				}),
			}),
		}),
		UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 1.08 }),
	})
end
