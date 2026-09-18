-- Description: Card sizing and content-aware packing for the storefront's track-based dashboard.

--!strict

local ResponsiveLayout = require(script.Parent.ResponsiveLayout)

local ShopLayout = {}

export type CardClass = {
	MinPx: number,
	MaxPx: number,
	Aspect: number,
	MinHeightPx: number,
	MaxHeightPx: number?,
	Layout: string,
	ArtScale: number?,
	NameScale: number,
	NameTextSize: number,
	ActionScale: number,
	ActionMinPx: number,
	ActionMaxPx: number,
	ShowHint: boolean,
}

export type Grid = {
	columns: number,
	rows: number,
	cardWidth: number,
	cardHeight: number,
	height: number,
}

export type Block = {
	span: number,
	height: number,
	[any]: any,
}

export type Placement = {
	block: Block,
	index: number,
	span: number,
	y: number,
}

-- Card size comes from the column count the width supports, not from the number
-- of cards, so equally classed cards stay the same size whether a section holds
-- one item or six; a section with fewer cards than columns simply uses fewer.
function ShopLayout.grid(available: number, count: number, class: CardClass, gap: number, maxColumns: number): Grid
	local columns, cardWidth = ResponsiveLayout.gridCellSize(available, class.MinPx, class.MaxPx, gap, maxColumns)
	-- Narrow columns would otherwise squash a landscape card until its name and
	-- price button had nowhere to go, so a card squares up rather than flattens.
	local cardHeight = math.max(math.floor(cardWidth * class.Aspect), class.MinHeightPx, 1)
	if class.MaxHeightPx then
		cardHeight = math.min(cardHeight, math.max(class.MinHeightPx, class.MaxHeightPx))
	end
	local rows = if count <= 0 then 0 else math.ceil(count / columns)
	return {
		columns = columns,
		rows = rows,
		cardWidth = cardWidth,
		cardHeight = cardHeight,
		height = if rows == 0 then 0 else rows * cardHeight + (rows - 1) * gap,
	}
end

-- An empty section collapses to its header plus a single placeholder strip
-- instead of reserving a card row it has nothing to put in.
function ShopLayout.sectionHeight(grid: Grid, headerHeight: number, emptyHeight: number): number
	return headerHeight + (if grid.rows == 0 then emptyHeight else grid.height)
end

-- A block with more cards than one row can hold keeps its first row where the
-- composition wants it and hands the remainder on to a second block, so its
-- cards stay full size instead of being flattened to fit.
function ShopLayout.splitFirstRow<T>(cards: { T }, columns: number): ({ T }, { T })
	local kept = math.clamp(columns, 1, math.max(#cards, 1))
	return table.move(cards, 1, kept, 1, {}), table.move(cards, kept + 1, #cards, 1, {})
end

-- The content area is divided into equal tracks whose pitch already carries the
-- gap, so a block of any span lands on the same lines as its neighbours and the
-- rightmost one ends exactly at the content edge.
function ShopLayout.trackUnit(available: number, tracks: number, gap: number): number
	return (available + gap) / math.max(tracks, 1)
end

function ShopLayout.trackOffset(unit: number, index: number): number
	return math.floor(index * unit + 0.5)
end

-- Width is a function of the span alone, never of where the block ends up, so
-- a block's height can be measured before the packer decides its position.
function ShopLayout.spanWidth(unit: number, span: number, gap: number): number
	return math.max(ShopLayout.trackOffset(unit, span) - gap, 1)
end

-- The narrowest a block may be and still read the way its class intends: one
-- card for a single offer, two side by side once it holds more than one.
function ShopLayout.minColumnWidth(count: number, class: CardClass, gap: number): number
	local cards = math.clamp(count, 1, 2)
	return class.MinPx * cards + gap * (cards - 1)
end

-- Widens a span until the block still reads the way its class intends, stepping
-- through the allowed spans so a block always lands on the same track lines.
function ShopLayout.resolveSpan(
	span: number,
	steps: { number },
	tracks: number,
	unit: number,
	gap: number,
	minWidth: number
): number
	for _, step in steps do
		if step >= span and ShopLayout.spanWidth(unit, step, gap) >= minWidth then
			return step
		end
	end
	return tracks
end

-- Keep the occupied rectangles, rather than only their highest point per
-- track: a wide section can bridge an empty space that a later narrow section
-- still fits. Candidate positions share an existing section's track edge.
local function fit(block: Block, placements: { Placement }, tracks: number, gap: number): Placement
	local span = math.clamp(block.span, 1, tracks)
	local starts: { [number]: boolean } = { [0] = true }
	local ordered = table.clone(placements)
	table.sort(ordered, function(a, b)
		return a.y < b.y
	end)
	for _, other in ordered do
		starts[other.index] = true
		starts[other.index + other.span] = true
	end
	local bestIndex, bestY, bestWaste = 0, math.huge, math.huge
	for index = 0, tracks - span do
		if not starts[index] then
			continue
		end
		local top = 0
		for _, other in ordered do
			local sharedTracks = index < other.index + other.span and other.index < index + span
			if sharedTracks and top < other.y + other.block.height + gap and top + block.height + gap > other.y then
				top = other.y + other.block.height + gap
			end
		end
		local waste = 0
		for track = index, index + span - 1 do
			local support = 0
			for _, other in ordered do
				local edge = other.y + other.block.height + gap
				if other.index <= track and track < other.index + other.span and edge <= top then
					support = math.max(support, edge)
				end
			end
			waste += top - support
		end
		if top < bestY or (top == bestY and waste < bestWaste) then
			bestIndex, bestY, bestWaste = index, top, waste
		end
	end
	return { block = block, index = bestIndex, span = span, y = bestY }
end

function ShopLayout.place(blocks: { Block }, tracks: number, gap: number): ({ Placement }, number)
	local placements = {}
	local bottom = 0
	for _, block in blocks do
		local placement = fit(block, placements, tracks, gap)
		table.insert(placements, placement)
		bottom = math.max(bottom, placement.y + block.height)
	end
	return placements, bottom
end

-- Compact one importance band without allowing another band to fill its open
-- columns. Within a band, sections still use the masonry packer and may trade
-- width for a shorter overall composition.
local function compactBand(blocks: { Block }, tracks: number, gap: number): ({ Placement }, number)
	local baseline = ShopLayout.place(blocks, tracks, gap)
	table.sort(baseline, function(a, b)
		return if a.y == b.y then a.index < b.index else a.y < b.y
	end)
	local placements = {}
	local bottom = 0
	for _, original in baseline do
		local selected = fit(original.block, placements, tracks, gap)
		for _, alternative in original.block.alternatives or {} do
			local candidate = fit(alternative, placements, tracks, gap)
			local selectedBottom = selected.y + selected.block.height
			local candidateBottom = candidate.y + candidate.block.height
			local lessUnused = candidate.y == selected.y
				and (candidate.block.unusedWidth or 0) < (selected.block.unusedWidth or 0)
			if
				candidateBottom < selectedBottom
				or (candidateBottom == selectedBottom and (candidate.y < selected.y or lessUnused))
			then
				selected = candidate
			end
		end
		table.insert(placements, selected)
		bottom = math.max(bottom, selected.y + selected.block.height)
	end
	return placements, bottom
end

-- Priority creates broad reading bands while the cards inside each band keep
-- the responsive masonry behaviour. Unranked blocks share the first band so
-- existing callers retain the original packing rules.
function ShopLayout.compact(blocks: { Block }, tracks: number, gap: number): ({ Placement }, number)
	local bands: { [number]: { Block } } = {}
	local priorities = {}
	for _, block in blocks do
		local priority = block.priority or 1
		if not bands[priority] then
			bands[priority] = {}
			table.insert(priorities, priority)
		end
		table.insert(bands[priority], block)
	end
	table.sort(priorities)

	local placements = {}
	local offset = 0
	for bandIndex, priority in priorities do
		local bandPlacements, bandBottom = compactBand(bands[priority], tracks, gap)
		for _, placement in bandPlacements do
			placement.y += offset
			table.insert(placements, placement)
		end
		offset += bandBottom
		if bandIndex < #priorities then
			offset += gap
		end
	end
	return placements, offset
end

return ShopLayout
