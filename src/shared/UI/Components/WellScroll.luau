--!strict
-- A fixed Figma well around a scrolling viewport. The frame artwork never
-- scrolls with the content; scroll refs and gamepad behavior stay on ScrollFrame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Well = require(script.Parent.Well)
local ScrollFrame = require(script.Parent.ScrollFrame)

return function(props)
	local scroll = table.clone(props.Native or {})
	local outer = {}
	for _, key in { "AnchorPoint", "Position", "Size", "LayoutOrder", "Visible", "ZIndex" } do
		outer[key] = scroll[key]
		scroll[key] = nil
	end
	local inset = props.InsetPx or 6
	scroll.ScrollRef = scroll.ref
	scroll.ref = nil
	scroll.AnchorPoint = Vector2.zero
	scroll.Position = UDim2.fromOffset(inset, inset)
	scroll.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ZIndex = outer.ZIndex
	return React.createElement(Well, { Native = outer, Ouch = props.Ouch }, {
		Content = React.createElement(ScrollFrame, scroll, props.children),
	})
end
