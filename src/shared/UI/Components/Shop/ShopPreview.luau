--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryPreview = require(script.Parent.Parent.InventoryPreview)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

return React.memo(function(props)
	if props.Thumbnail ~= nil and props.Thumbnail ~= "" then
		return c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Thumbnail,
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.82, 0.82),
			ZIndex = props.ZIndex or 5,
		})
	end
	if #props.Items == 0 then
		return c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 34,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.55),
				Text = props.Placeholder or "COMING SOON",
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = 0.15,
				ZIndex = props.ZIndex or 5,
			},
		})
	end

	local children = {}
	local count = math.min(#props.Items, 3)
	for index = 1, count do
		local entry = props.Items[index]
		local width = if count == 1 then 1 else 0.54
		local x = if count == 1 then 0.5 else 0.2 + (index - 1) * (0.6 / math.max(count - 1, 1))
		children[entry.itemId] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(width, 1),
			ZIndex = (props.ZIndex or 5) + index,
		}, {
			Preview = c(InventoryPreview, {
				ItemId = entry.itemId,
				Category = entry.category,
				Definition = entry.definition,
				ZIndex = (props.ZIndex or 5) + index,
			}),
		})
	end
	return c(React.Fragment, nil, children)
end)
