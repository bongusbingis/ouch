-- Description: Pure formatting for the mode ballot: vote count text and the clamped countdown fraction derived from server time.

--!strict

local ResponsiveLayout = require(script.Parent.ResponsiveLayout)
local T = require(script.Parent.Parent.Tokens)

local GameModeVoteViewModel = {}

export type MapDefinition = {
	Enabled: boolean,
	DisplayName: string,
	ShortName: string,
	ThumbnailId: string,
	SortOrder: number,
	Accent: string,
}

export type MapsConfig = { Maps: { [string]: MapDefinition } }

export type MapSnapshot = {
	mapOptions: { string }?,
	mapVoteCounts: { [string]: number }?,
	selectedMapId: string?,
}

export type MapChip = {
	Id: string,
	Title: string,
	ShortName: string,
	ThumbnailId: string,
	Accent: Color3,
	SortOrder: number,
	VoteCount: number,
	Selected: boolean,
}

export type DockLayout = {
	stacked: boolean,
	chipHeight: number,
	chipWidth: number,
	barWidth: number,
	barHeight: number,
	gap: number,
	holderShrink: number,
}

-- projectedTarget is the target this roster would actually play to, published on
-- the ballot by the server. The authored rules value is only the number at the
-- mode's reference roster, so selling that one would promise a match length
-- nobody is about to play.
function GameModeVoteViewModel.description(rules: any, teamMode: boolean, projectedTarget: number?): string
	local target = projectedTarget or rules.ScoreTarget
	if target == math.huge then
		return "Survive until time runs out. Eliminated survivors join the infected."
	end
	local goal = if teamMode
		then `First team to {target} eliminations wins.`
		else `First to {target} eliminations wins.`
	return goal .. (if teamMode then " Parties stay together." else " Everyone is a target.")
end

-- Short-landscape breakpoint shared with the arena HUD so the ballot and the HUD compact together.
function GameModeVoteViewModel.isShort(safeSize: Vector2): boolean
	return safeSize.Y <= T.ArenaHUD.ShortHeight
end

function GameModeVoteViewModel.formatVoteCount(count: number): string
	local total = math.max(0, math.floor(count))
	return `{total} {if total == 1 then "VOTE" else "VOTES"}`
end

function GameModeVoteViewModel.progress(now: number, endsAt: number, durationSeconds: number): number
	if durationSeconds <= 0 then
		return 0
	end
	return math.clamp((endsAt - now) / durationSeconds, 0, 1)
end

-- Offered maps the client knows how to draw, in ballot order. Fewer than two means
-- there is nothing to choose, so the ballot stays mode-only.
function GameModeVoteViewModel.mapChips(
	snapshot: MapSnapshot,
	maps: MapsConfig,
	accent: (string) -> Color3,
	imageId: ((any) -> string)?
): { MapChip }
	local chips: { MapChip } = {}
	local seen: { [string]: boolean } = {}
	for _, mapId in snapshot.mapOptions or {} do
		local definition = maps.Maps[mapId]
		if definition ~= nil and definition.Enabled and not seen[mapId] then
			seen[mapId] = true
			table.insert(chips, {
				Id = mapId,
				Title = definition.DisplayName,
				ShortName = definition.ShortName,
				ThumbnailId = if imageId then imageId(definition.ThumbnailId) else definition.ThumbnailId,
				Accent = accent(definition.Accent),
				SortOrder = definition.SortOrder,
				VoteCount = (snapshot.mapVoteCounts or {})[mapId] or 0,
				Selected = snapshot.selectedMapId == mapId,
			})
		end
	end
	if #chips < 2 then
		return {}
	end
	table.sort(chips, function(a, b)
		if a.SortOrder ~= b.SortOrder then
			return a.SortOrder < b.SortOrder
		end
		return a.Id < b.Id
	end)
	return chips
end

-- Pixel geometry of the map dock inside the ballot's safe area. Landscape puts the
-- chips and the countdown bar on one row; when the bar would shrink below its
-- minimum (or there are many maps) and always in portrait, the chips take their
-- own row above it and the mode-card holder gives up that height.
function GameModeVoteViewModel.dockLayout(safeSize: Vector2, chipCount: number): DockLayout
	local M = T.MapVote
	local portrait = ResponsiveLayout.isPortrait(safeSize, 1)
	local compact = not portrait and GameModeVoteViewModel.isShort(safeSize)
	local count = math.max(chipCount, 1)
	local gap = M.Gap
	local usable = math.floor(safeSize.X * M.EdgeFill)
	local chipHeight = if portrait
		then M.PortraitChipHeight
		else if compact
			then M.CompactChipHeight
			else math.clamp(math.floor(safeSize.Y * M.ChipHeightScale), M.ChipHeightMin, M.ChipHeightMax)
	local barHeight = if portrait or compact then M.CompactBarHeight else M.BarHeight
	local soloBar = math.min(M.BarMaxWidth, math.floor(safeSize.X * 0.82))
	local chipWidth = if compact
		then M.CompactChipWidth
		else math.clamp(math.floor(chipHeight * M.ChipWidthPerHeight), M.ChipWidthMin, M.ChipWidthMax)
	local stacked = portrait
	local barWidth = soloBar
	if not portrait then
		local inline = usable - count * chipWidth - (count - 1) * gap - gap
		stacked = count > M.MaxInlineChips or inline < M.BarMinWidth
		if not stacked then
			barWidth = math.min(M.BarMaxWidth, inline)
		end
	end
	if stacked then
		chipWidth = math.min(chipWidth, math.floor((usable - gap * (count - 1)) / count))
	end
	return {
		stacked = stacked,
		chipHeight = chipHeight,
		chipWidth = chipWidth,
		barWidth = barWidth,
		barHeight = barHeight,
		gap = gap,
		holderShrink = if stacked then chipHeight + gap else 0,
	}
end

function GameModeVoteViewModel.title(hasMaps: boolean): string
	return if hasMaps then "VOTE MODE & MAP" else "VOTE FOR A MODE"
end

return table.freeze(GameModeVoteViewModel)
