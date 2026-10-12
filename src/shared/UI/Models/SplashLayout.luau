--!strict
-- One composition for the visible splash UI and the party camera's clear window.
local T = require(script.Parent.Parent.Tokens)
local Header = require(script.Parent.LobbyHeaderLayout)
local S = T.Splash
local SplashLayout = {}

local function rect(x, y, w, h)
	return { position = Vector2.new(x, y), size = Vector2.new(math.max(1, w), math.max(1, h)) }
end

-- Landscape phones stack the season summary tighter: title, bar and XP line in
-- 76 px, then the 44 px reward actions.
local LANDSCAPE_SEASON_CONTENT = 76 + 44

-- Height of the season summary the progression hub draws.
function SplashLayout.seasonContentHeight(landscape: boolean?): number
	return if landscape then LANDSCAPE_SEASON_CONTENT else S.SeasonContentHeight
end

-- Season and Daily fit their summary so the panel never sits mostly empty; Quests
-- takes the space it is given and scrolls.
local function progressHeight(available: number, tab: string?, compact: boolean, landscape: boolean?): number
	local content = if tab == "QUESTS"
		then nil
		elseif tab == "DAILY" then S.DailyContentHeight
		else SplashLayout.seasonContentHeight(landscape)
	local contentTop = if compact then S.CompactProgressContentTop else S.ProgressContentTop
	return math.max(
		1,
		if content then math.min(available, contentTop + content + S.ProgressContentBottom) else available
	)
end

function SplashLayout.resolve(
	size: Vector2,
	showStatus: boolean?,
	tab: string?,
	hasSelectedMode: boolean?,
	headerHeight: number?
)
	local compact = size.X < S.WideMin or size.Y < S.TallMin
	local portrait = size.X < 540
	local edge = if compact then S.CompactEdge else S.Edge
	local top = Header.resolve(size).height + (if compact then S.CompactHeaderGap else S.HeaderGap)
	local footerHeight = if portrait then S.PortraitFooterHeight else S.CompactFooterHeight
	if compact and not portrait then
		local l = T.LobbyLandscape
		local landscapeTop = (headerHeight or Header.resolve(size).height) + l.HeaderGap
		local width = math.min(math.floor((size.X - edge * 2) * l.ProgressFraction), l.ProgressMaxWidth)
		local x = size.X - edge - width
		local footerY = size.Y - edge - l.ActionHeight
		local statusHeight = if showStatus then l.StatusHeight else 0
		local height = math.max(1, footerY - l.Gap - landscapeTop - statusHeight)
		local progress = progressHeight(height, tab, true, true)
		return {
			compact = true,
			portrait = false,
			landscape = true,
			body = rect(x, landscapeTop, width, height),
			progress = rect(x, landscapeTop, width, progress),
			footer = rect(edge, footerY, size.X - edge * 2, l.ActionHeight),
			world = rect(edge, landscapeTop, x - edge - l.Gap, footerY - l.Gap - landscapeTop),
			party = rect(edge, landscapeTop, l.PartyButtonWidth, l.ActionHeight),
			progressHeight = progress,
			modeExtra = 0,
		}
	end
	if compact then
		local width = size.X - edge * 2
		local progress = progressHeight(size.Y - top - edge - footerHeight - S.CompactGap, tab, true)
		return {
			compact = true,
			portrait = portrait,
			body = rect(edge, top, width, progress),
			progress = rect(edge, top, width, size.Y - top - edge),
			footer = rect(edge, top + progress + S.CompactGap, width, footerHeight),
			world = rect(edge, top, width, size.Y - top - edge),
			progressHeight = progress,
			modeExtra = 0,
		}
	end
	local width = math.clamp(size.X * S.ColumnFraction, S.ColumnMin, S.ColumnMax)
	local x = size.X - edge - width
	local height = size.Y - top - edge
	local actionHeight = S.ActionPanelHeight + (if showStatus then S.StatusHeight + 4 else 0)
	local progress = progressHeight(math.max(S.ProgressMinHeight, height - actionHeight - S.Gap), tab, false)
	local spare = math.max(0, height - progress - S.Gap - actionHeight)
	local modeExtra = if hasSelectedMode and (tab == nil or tab == "SEASON" or tab == "DAILY")
		then math.min(S.ModeExpandedMaxHeight - S.ModeRowHeight, math.floor(spare * S.ModeSpareFraction))
		else 0
	if modeExtra < S.ModeExpandMinExtra then
		modeExtra = 0
	end
	return {
		compact = false,
		portrait = false,
		body = rect(x, top, width, height),
		world = rect(edge, top, x - edge * 2, height),
		actionHeight = actionHeight + modeExtra,
		modeExtra = modeExtra,
		progressHeight = progress,
	}
end

return table.freeze(SplashLayout)
