--!strict

-- Screen zones as plain data. The input layer owns rectangles, never instances,
-- so nothing here knows what a GuiObject is and react-lua can read the same
-- rects to align affordances against them later.
--
-- Rects are normalized (0-1 of the usable viewport). Pixel conversion is a
-- separate step that folds in the GUI inset, because the usable area is the
-- viewport minus the topbar, not the raw viewport.

local Zones = {}

export type Rect = {
	x: number,
	y: number,
	width: number,
	height: number,
}

export type Layout = {
	Movement: Rect,
	Action: Rect,
}

-- Left thumb drives movement, right thumb acts; mirrored when left-handed.
function Zones.layout(movementWidthFraction: number, leftHanded: boolean): Layout
	local width = math.clamp(movementWidthFraction, 0, 1)
	local movementX = if leftHanded then 1 - width else 0
	local actionX = if leftHanded then 0 else width
	return {
		Movement = { x = movementX, y = 0, width = width, height = 1 },
		Action = { x = actionX, y = 0, width = 1 - width, height = 1 },
	}
end

function Zones.contains(rect: Rect, x: number, y: number): boolean
	return x >= rect.x and x < rect.x + rect.width and y >= rect.y and y < rect.y + rect.height
end

-- Normalized rect to pixels within the usable area. insetX/insetY are the
-- top-left GUI inset; a touch's raw screen position must have the same inset
-- subtracted before it is compared against these.
function Zones.toPixels(rect: Rect, viewportWidth: number, viewportHeight: number, insetX: number, insetY: number): Rect
	local usableWidth = math.max(viewportWidth - insetX, 0)
	local usableHeight = math.max(viewportHeight - insetY, 0)
	return {
		x = insetX + rect.x * usableWidth,
		y = insetY + rect.y * usableHeight,
		width = rect.width * usableWidth,
		height = rect.height * usableHeight,
	}
end

-- Raw screen position to normalized usable-area coordinates. Returns nil when
-- the point sits inside the inset (under the topbar), which is never ours.
function Zones.normalize(
	x: number,
	y: number,
	viewportWidth: number,
	viewportHeight: number,
	insetX: number,
	insetY: number
): (number?, number?)
	local usableWidth = viewportWidth - insetX
	local usableHeight = viewportHeight - insetY
	if usableWidth <= 0 or usableHeight <= 0 then
		return nil, nil
	end
	local normalizedX = (x - insetX) / usableWidth
	local normalizedY = (y - insetY) / usableHeight
	if normalizedX < 0 or normalizedY < 0 then
		return nil, nil
	end
	return normalizedX, normalizedY
end

-- Exclusion rects are registered by UI once it exists: a touch landing inside
-- one belongs to that control, not to the tap-anywhere handler.
function Zones.excluded(rects: { Rect }, x: number, y: number): boolean
	for _, rect in rects do
		if Zones.contains(rect, x, y) then
			return true
		end
	end
	return false
end

-- Thresholds are authored against a reference height so a tablet and a phone
-- ask for the same physical thumb travel rather than the same pixel count.
function Zones.scalePixels(referencePixels: number, viewportHeight: number, referenceHeight: number): number
	if referenceHeight <= 0 then
		return referencePixels
	end
	return referencePixels * (viewportHeight / referenceHeight)
end

return table.freeze(Zones)
