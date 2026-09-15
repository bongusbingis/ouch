--!strict
-- Roblox can render rotated descendants outside a ScrollingFrame's clipping bounds.
local ScrollingClipping = {}

function ScrollingClipping.isInsideClippingScrollingFrame(target: Instance?): boolean
	local current = target
	while current do
		if current:IsA("ScrollingFrame") and current.ClipsDescendants then
			return true
		end
		current = current.Parent
	end
	return false
end

return table.freeze(ScrollingClipping)
