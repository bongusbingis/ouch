--!strict
-- Raised cyan panel with feathered native shadows and a darker side/bottom.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local UI = require(ReplicatedStorage.Config.Interface.UI)
local c = React.createElement

export type Props = {
	Native: { [any]: any }?,
	Color: Color3?,
	Radius: number?,
	Padding: number?,
	Gloss: boolean?,
	children: { [any]: any }?,
}

return function(props: Props)
	local native = table.clone(props.Native or {})
	local color = props.Color or native.BackgroundColor3 or UI.ProgressionStyle.Panel
	local radius = props.Radius or UI.Panel.RadiusPx
	local z = native.ZIndex or 1
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Size = native.Size or UDim2.fromScale(1, 1)
	local children = {}
	for index = 1, 3 do
		local spread = index * 2
		children[`Shadow{index}`] = c("Frame", {
			BackgroundColor3 = UI.ProgressionStyle.Ink,
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(2 - spread, UI.Panel.BevelPx + 4 - spread),
			Size = UDim2.new(1, spread * 2, 1, spread * 2),
			ZIndex = z,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, radius + spread) }),
			SoftEdge = c("UIStroke", { Color = UI.ProgressionStyle.Ink, Thickness = 2, Transparency = 0.98 }),
			Fade = c("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.8, 0) }),
		})
	end
	children.Bevel = c("Frame", {
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.26),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, UI.Panel.BevelPx),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
	}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	local content = table.clone(props.children or {})
	-- Constraints and scale belong to the whole panel, including its shadow.
	for key, child in content do
		local kind = if React.isValidElement(child) then child.type else nil
		if kind == "UIScale" or kind == "UISizeConstraint" or kind == "UIAspectRatioConstraint" then
			children[key] = child
			content[key] = nil
		end
	end
	local padding = if props.Padding ~= nil then props.Padding else UI.Panel.InsetPx
	if padding > 0 then
		content.Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
		})
		content = {
			Content = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, content),
		}
	end
	content.Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) })
	content.Outline = c("UIStroke", { Color = color:Lerp(UI.ProgressionStyle.White, 0.55), Thickness = 1.5 })
	content.Gloss = if props.Gloss
		then c("Frame", {
			BackgroundColor3 = UI.ProgressionStyle.White,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) }),
			Fade = c("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.85),
					NumberSequenceKeypoint.new(0.33, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		else nil
	children.Face = c("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
	}, content)
	return c(if native.Image ~= nil then "ImageLabel" else "Frame", native, children)
end
