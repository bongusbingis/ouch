-- Restores focus only to a mounted, visible control in an enabled screen.
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

return Selection
