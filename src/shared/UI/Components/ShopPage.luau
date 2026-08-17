--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))

return function(props)
	return React.createElement("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://101245842230886",
		ImageColor3 = Color3.fromRGB(193, 255, 251),
		LayoutOrder = 5,
		Position = props.Position or UDim2.fromScale(-0.005, 0.127),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(0.602, 0.748),
		SliceCenter = Rect.new(0, 278, 885, 655),
	})
end
