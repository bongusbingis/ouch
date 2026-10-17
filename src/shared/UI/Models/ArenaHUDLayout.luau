--!strict
-- Full-screen geometry: use free topbar space and keep input targets clear of cutouts.
local T = require(script.Parent.Parent.Tokens)
local S = T.ArenaHUD
local Layout = {}

-- hints: extra width the Menu/Scores buttons need for their "[key] LABEL" hint
-- (InputHint.reserve; zero on touch, where no hint renders).
export type HintWidths = { menu: number, scores: number }

function Layout.resolve(viewport: Vector2, device: Rect, topbar: Rect, touch: boolean?, hints: HintWidths?)
	local compact = touch == true or viewport.Y <= S.ShortHeight or viewport.X < S.NarrowWidth
	local edge, gap, target = S.Edge, S.Gap, T.Layout.MinTarget
	local left, right = device.Min.X + edge, device.Max.X - edge
	local width = math.min(if compact then S.CompactWidth else S.Width, math.max(right - left, 1))
	local height = if compact then S.CompactHeight else S.Height
	local menuWidth = S.MenuWidth + (if hints then hints.menu else 0)
	local scoresWidth = S.ScoresWidth + (if hints then hints.scores else 0)
	local actionsWidth = menuWidth + gap + scoresWidth
	-- TopbarInset is relative to the device-safe origin, not the CoreUI origin.
	local freeLeft = math.max(left, device.Min.X + topbar.Min.X + gap)
	local freeRight = math.min(right, device.Min.X + topbar.Max.X - gap)
	local barHeight = topbar.Max.Y - topbar.Min.Y
	local docked = compact and barHeight >= target and freeRight - freeLeft >= width + gap + actionsWidth
	local actionsRight = if freeRight - freeLeft >= actionsWidth then freeRight else right
	local actionTop = device.Min.Y + math.max(0, topbar.Min.Y) + math.max(0, (barHeight - target) / 2)
	local top = math.max(device.Min.Y + edge, device.Min.Y + topbar.Max.Y + gap)
	local hudLeft = math.clamp((viewport.X - width) / 2, left, math.max(left, right - width))
	if docked then
		hudLeft = math.clamp(hudLeft, freeLeft, freeRight - actionsWidth - gap - width)
		top = math.max(device.Min.Y + 6, device.Min.Y + topbar.Min.Y + (barHeight - height) / 2)
	elseif freeRight - freeLeft < actionsWidth or barHeight < target then
		actionTop = top
		top += target + gap
	end
	local bottom = viewport.Y - device.Max.Y + S.ToolbarBottom
	local toolbarWidth =
		math.max(88, math.min(S.ToolbarWidth, device.Max.X - device.Min.X - edge * 2 - S.EmoteSize - gap))
	local toolbarLeft = math.max((viewport.X - toolbarWidth) / 2, left + S.EmoteSize + gap)
	return {
		compact = compact,
		docked = docked,
		hud = { position = Vector2.new(hudLeft, top), size = Vector2.new(width, height) },
		menu = {
			position = Vector2.new(actionsRight - menuWidth, actionTop),
			size = Vector2.new(menuWidth, target),
		},
		scores = {
			position = Vector2.new(actionsRight - actionsWidth, actionTop),
			size = Vector2.new(scoresWidth, target),
		},
		toolbar = {
			position = Vector2.new(toolbarLeft, viewport.Y - bottom - S.ToolbarHeight),
			size = Vector2.new(toolbarWidth, S.ToolbarHeight),
		},
		emote = {
			position = Vector2.new(toolbarLeft - gap - S.EmoteSize, viewport.Y - bottom - S.EmoteSize),
			size = Vector2.new(S.EmoteSize, S.EmoteSize),
		},
	}
end

return table.freeze(Layout)
