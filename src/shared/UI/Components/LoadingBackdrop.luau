-- Description: The shared full-screen backdrop the loading and transition screens are drawn on.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))

local c = React.createElement

export type Props = {
	Transparency: any?,
	RootRef: any?,
	Native: { [any]: any }?,
	children: { [any]: any }?,
}

local function merge(...): { [any]: any }
	local result = {}
	for index = 1, select("#", ...) do
		local source = select(index, ...)
		if source then
			for key, value in source do
				result[key] = value
			end
		end
	end
	return result
end

return function(props: Props)
	return c(
		"CanvasGroup",
		merge({
			ref = props.RootRef,
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(102, 232, 255),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			GroupTransparency = props.Transparency or 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,
		}, props.Native),
		props.children
	)
end
