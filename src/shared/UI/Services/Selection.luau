-- Validates focus targets and reveals selected controls inside scrollable menus.
--!strict

local Selection = {}

function Selection.isSelectable(button: GuiObject?): boolean
	if button == nil or button.Parent == nil or not button.Selectable then
		return false
	end
	local ancestor: Instance? = button
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("ScreenGui") then
			return ancestor.Enabled and ancestor:IsDescendantOf(game)
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function scrollAxis(start: number, extent: number, position: number, window: number, canvas: number): number
	local target = position
	if start < position then
		target = start
	elseif start + extent > position + window then
		target = math.min(start, start + extent - window)
	end
	return math.clamp(target, 0, math.max(0, canvas - window))
end

function Selection.scrollIntoView(button: GuiObject)
	local ancestor = button.Parent
	while ancestor do
		if ancestor:IsA("ScrollingFrame") and ancestor.AbsoluteWindowSize.Y > 0 then
			local position = ancestor.CanvasPosition
			local start = button.AbsolutePosition - ancestor.AbsolutePosition + position
			local extent, window, canvas = button.AbsoluteSize, ancestor.AbsoluteWindowSize, ancestor.AbsoluteCanvasSize
			ancestor.CanvasPosition = Vector2.new(
				scrollAxis(start.X, extent.X, position.X, window.X, canvas.X),
				scrollAxis(start.Y, extent.Y, position.Y, window.Y, canvas.Y)
			)
		end
		ancestor = ancestor.Parent
	end
end

return Selection
