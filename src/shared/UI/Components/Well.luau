-- Name: Well.luau
-- Author: Jack C.
-- Description: The one inner container: a darker-blue recessed field built exactly like the page panel (white outline, solid black bottom-right drop shadow, Control radius) so cards and rows sit on the same construction everywhere; renders the Figma 9-slice when one is configured and the identical native recipe otherwise.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

local c = React.createElement
local OuchPanel = require(script.Parent.OuchPanel)
local Palette = UIConfig.ProgressionStyle

export type Props = {
	Ouch: boolean?,
	Color: Color3?,
	Radius: number?,
	Shadow: boolean?,
	StrokeTransparency: number?,
	AspectRatio: number?,
	Native: { [any]: any }?,
	children: any?,
}

return function(props: Props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	native.Size = native.Size or UDim2.fromScale(1, 1)
	local radius = props.Radius or UIConfig.Radius.Control
	local color = props.Color or Palette.Claimed
	local shadow = if props.Shadow == false then 0 else UIConfig.Well.ShadowPx
	local z = native.ZIndex or 1
	local artwork = UIConfig.Layout.WellSurface
	local content = table.clone(props.children or {})
	if props.Ouch then
		-- Preserve the authored skin reference and all content bounds under the native face.
		native.Image = artwork.Image
		native.ScaleType = Enum.ScaleType.Slice
		native.SliceCenter = artwork.SliceCenter
		native.SliceScale = artwork.SliceScale
		return c(OuchPanel, {
			Native = native,
			Padding = 0,
			Gloss = true,
			Color = props.Color or Palette.PanelRaised,
			Radius = radius,
		}, content)
	end
	-- The aspect constraint has to size the whole well (face and shadow), so it
	-- lives on the outer element rather than among the children.
	local aspect = if props.AspectRatio
		then c("UIAspectRatioConstraint", {
			AspectRatio = props.AspectRatio,
			AspectType = Enum.AspectType.FitWithinMaxSize,
		})
		else nil
	if
		artwork.Image ~= ""
		and radius == UIConfig.Radius.Control
		and color == Palette.Claimed
		and props.StrokeTransparency == nil
		and shadow > 0
	then
		content.Aspect = aspect
		native.Image = artwork.Image
		native.ScaleType = Enum.ScaleType.Slice
		native.SliceCenter = artwork.SliceCenter
		native.SliceScale = artwork.SliceScale
		return c("ImageLabel", native, content)
	end
	content.Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) })
	content.Outline = c("UIStroke", {
		Color = Palette.White,
		Thickness = UIConfig.Well.StrokePx,
		Transparency = props.StrokeTransparency or 0,
	})
	return c("Frame", native, {
		Aspect = aspect,
		Shadow = if shadow > 0
			then c("Frame", {
				BackgroundColor3 = Palette.Shadow,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(shadow, shadow),
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) }) })
			else nil,
		Face = c("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z + 1,
		}, content),
	})
end
