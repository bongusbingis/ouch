-- Description: Pure layout model for the storefront dashboard: the card grid a block fills its span with, and the track-based packer that places each block at the earliest position its span will fit so a taller neighbour never leaves a hole beneath a shorter one.

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

-- Places each block at the lowest position its span will fit, over the track
-- lines already established by the blocks before it. This is what stops a
-- taller neighbour from leaving a hole: a block whose span fits under the
-- shorter of two adjacent blocks starts there rather than waiting for the
-- taller one to finish. Blocks are never reordered -- each one only chooses
-- where it goes -- and candidate positions are limited to the left edge and the
-- right edges of blocks already placed, so every block lines up with one of its
-- neighbours instead of floating at an arbitrary offset. Ties on height go to
-- the position that buries the least empty space, then to the leftmost.
function ShopLayout.place(blocks: { Block }, tracks: number, gap: number): ({ Placement }, number)
	local heights = table.create(tracks, 0)
	local starts: { [number]: boolean } = { [0] = true }
	local placements = {}
	local bottom = 0
	for _, block in blocks do
		local span = math.clamp(block.span, 1, tracks)
		local bestIndex, bestY, bestWaste = 0, math.huge, math.huge
		for index = 0, tracks - span do
			if starts[index] then
				local top = 0
				for track = index + 1, index + span do
					top = math.max(top, heights[track])
				end
				local waste = 0
				for track = index + 1, index + span do
					waste += top - heights[track]
				end
				if top < bestY or (top == bestY and waste < bestWaste) then
					bestIndex, bestY, bestWaste = index, top, waste
				end
			end
		end
		table.insert(placements, { block = block, index = bestIndex, span = span, y = bestY })
		for track = bestIndex + 1, bestIndex + span do
			heights[track] = bestY + block.height + gap
		end
		starts[bestIndex + span] = true
		bottom = math.max(bottom, bestY + block.height)
	end
	return placements, bottom
end

return ShopLayout
