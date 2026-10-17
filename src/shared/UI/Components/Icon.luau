--!strict
-- Licensed glyphs share two white-mask atlases; all UI uses the same crop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Artwork = require(ReplicatedStorage.Config.Interface.RedesignArtwork)

return function(props)
	local entry = Artwork.Icons[props.Name]
	if not entry or entry.Image == "" then
		return nil
	end
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Image = entry.Image
	native.ImageRectOffset = entry.Offset
	native.ImageRectSize = entry.Size
	native.ImageColor3 = props.Color or Color3.new(1, 1, 1)
	native.ScaleType = Enum.ScaleType.Fit
	native.Size = native.Size or UDim2.fromScale(1, 1)
	return React.createElement("ImageLabel", native, props.children)
end
