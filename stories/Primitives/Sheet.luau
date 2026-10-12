--[[
    Layout chrome shared by the Primitives stories (not a story): a padded, wrapping sheet of
    labelled cells, each cell an element in a fixed w x h box with a caption under it. Story chrome
    only -- the captions are not Ouch typography.
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)

local React = StoryRoot.React
local c = React.createElement

local CAPTION = 22

local Sheet = {}

function Sheet.slot(order: number, label: string, size: Vector2, element: any): any
	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y + CAPTION),
	}, {
		Box = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size.X, size.Y) }, {
			Element = element,
		}),
		Caption = StoryRoot.Text({
			Position = UDim2.fromOffset(0, size.Y + 4),
			Size = UDim2.new(1, 0, 0, CAPTION - 4),
			Text = label,
			TextSize = 14,
		}),
	})
end

--> cells: a list of elements (usually Sheet.slot results); gap defaults to 28.
function Sheet.sheet(cells: { any }, gap: number?): any
	local children: { [string]: any } = {
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 24),
			PaddingTop = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 24),
		}),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap or 28),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	}
	for index, cell in cells do
		children[`Cell{index}`] = cell
	end
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, children)
end

--> Shallow merge, later tables win.
function Sheet.merge(...: { [string]: any }?): { [string]: any }
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

return Sheet
