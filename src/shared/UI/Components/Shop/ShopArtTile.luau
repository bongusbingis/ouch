-- Name: ShopArtTile.luau
-- Author: Jack C.
-- Description: The recessed artwork well inside a storefront card: an accent-tinted field with a matching line and the faint Backpack swirl, so the art has an interior to sit in and the card gains a layer without another ink rectangle.
-- Created: 2026-09-15
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local T = require(script.Parent.Parent.Parent.Tokens)

local c = React.createElement

export type Props = {
	Color: Color3,
	LineColor: Color3,
	Position: UDim2,
	Size: UDim2,
	ZIndex: number?,
	children: { [any]: any }?,
}

return function(props: Props)
	local z = props.ZIndex or 8
	local content = table.clone(props.children or {})
	content.Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shop.TileRadius) })
	content.Outline = c("UIStroke", { Color = props.LineColor, Thickness = T.Shape.StrokeInner })
	content.Texture = c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = T.Texture.Swirl,
		ImageColor3 = T.Colors.Surface,
		ImageTransparency = 0.95,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
	}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shop.TileRadius) }) })
	return c("Frame", {
		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,
		Position = props.Position,
		Size = props.Size,
		ZIndex = z,
	}, content)
end
