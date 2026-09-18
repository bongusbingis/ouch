--!strict

local T = require(script.Parent.TestKit)
local ShopLayout = require(script.Parent.Parent.UI.Models.ShopLayout)

-- Mirrors Config.Interface.UI.Layout.Shop, which cannot be required headlessly
-- because it builds Font values.
local CARD_GAP = 12
local GAP = 20
local TRACKS = 12
local STEPS = { 4, 8, 12 }
local HEADER = 38
local EMPTY = 54
local CLASSES = {
	Pass = { MinPx = 130, MaxPx = 300, Aspect = 1, MinHeightPx = 210 },
	Tile = { MinPx = 140, MaxPx = 200, Aspect = 1.04, MinHeightPx = 170 },
	Feature = { MinPx = 150, MaxPx = 235, Aspect = 0.86, MinHeightPx = 190 },
	Promo = { MinPx = 210, MaxPx = 560, Aspect = 0.44, MinHeightPx = 150 },
}

local function block(id: string, span: number, height: number)
	return { id = id, span = span, height = height }
end

local function placedBy(placements): { [string]: any }
	local byId = {}
	for _, placement in placements do
		byId[placement.block.id] = placement
	end
	return byId
end

local function overlaps(placements, gap: number?): boolean
	for i = 1, #placements do
		for j = i + 1, #placements do
			local a, b = placements[i], placements[j]
			local sameTracks = a.index < b.index + b.span and b.index < a.index + a.span
			local aBottom = a.y + a.block.height
			local bBottom = b.y + b.block.height
			local sameRows = a.y < bBottom + (gap or 0) and b.y < aBottom + (gap or 0)
			if sameTracks and sameRows then
				return true
			end
		end
	end
	return false
end

T.describe("ShopLayout", function()
	T.it("fits a complete card row below its heading on a short landscape phone", function()
		local class = table.clone(CLASSES.Pass)
		class.MinHeightPx = 120
		class.MaxHeightPx = 120
		local grid = ShopLayout.grid(460, 3, class, CARD_GAP, 4)
		T.expect(grid.rows):toEqual(1)
		T.expect(ShopLayout.sectionHeight(grid, HEADER, EMPTY) <= 160):toBeTruthy()
		T.expect(ShopLayout.grid(1046, 3, CLASSES.Pass, CARD_GAP, 4).cardHeight > 120):toBeTruthy()
	end)
	T.it("keeps a card class the same size whatever a section holds", function()
		local one = ShopLayout.grid(1046, 1, CLASSES.Pass, CARD_GAP, 4)
		local eight = ShopLayout.grid(1046, 8, CLASSES.Pass, CARD_GAP, 4)
		T.expect(one.cardWidth):toEqual(eight.cardWidth)
		T.expect(one.cardHeight):toEqual(eight.cardHeight)
		T.expect(one.rows):toEqual(1)
		T.expect(eight.rows):toEqual(2)
		T.expect(eight.height):toEqual(eight.cardHeight * 2 + CARD_GAP)
	end)

	T.it("wraps odd counts without reserving an unused row", function()
		local three = ShopLayout.grid(1046, 3, CLASSES.Pass, CARD_GAP, 4)
		T.expect(three.columns):toEqual(4)
		T.expect(three.rows):toEqual(1)
		T.expect(ShopLayout.grid(1046, 5, CLASSES.Pass, CARD_GAP, 4).rows):toEqual(2)
	end)

	T.it("collapses an empty section to a header and a single strip", function()
		local grid = ShopLayout.grid(1046, 0, CLASSES.Tile, CARD_GAP, 4)
		T.expect(grid.rows):toEqual(0)
		T.expect(grid.height):toEqual(0)
		T.expect(ShopLayout.sectionHeight(grid, HEADER, EMPTY)):toEqual(HEADER + EMPTY)
	end)

	T.it("drops columns and honours the class floor as the width narrows", function()
		local wide = ShopLayout.grid(1046, 4, CLASSES.Pass, CARD_GAP, 4)
		local narrow = ShopLayout.grid(288, 4, CLASSES.Pass, CARD_GAP, 4)
		T.expect(wide.columns):toEqual(4)
		T.expect(narrow.columns):toEqual(2)
		T.expect(narrow.cardHeight >= CLASSES.Pass.MinHeightPx):toBeTruthy()
	end)

	T.it("hands a block's overflow on rather than flattening it to fit one row", function()
		local cards = { "a", "b", "c", "d", "e", "f", "g", "h" }
		local grid = ShopLayout.grid(1046, #cards, CLASSES.Pass, CARD_GAP, 4)
		local featured, rest = ShopLayout.splitFirstRow(cards, grid.columns)
		T.expect(#featured):toEqual(4)
		T.expect(#rest):toEqual(4)
		T.expect(featured[1]):toEqual("a")
		T.expect(rest[1]):toEqual("e")

		local whole, none = ShopLayout.splitFirstRow({ "a", "b" }, 4)
		T.expect(#whole):toEqual(2)
		T.expect(#none):toEqual(0)
	end)

	T.it("splits the featured passes using the wider short-landscape cards", function()
		local class = table.clone(CLASSES.Pass)
		class.MinPx = 210
		class.MinHeightPx = 120
		class.MaxHeightPx = 120
		local cards = { "a", "b", "c", "d", "e" }
		local grid = ShopLayout.grid(460, #cards, class, CARD_GAP, 4)
		local first, rest = ShopLayout.splitFirstRow(cards, grid.columns)
		T.expect(#first):toEqual(2)
		T.expect(#rest):toEqual(3)
		local featured = ShopLayout.grid(460, #first, class, CARD_GAP, 4)
		T.expect(featured.rows):toEqual(1)
		T.expect(ShopLayout.sectionHeight(featured, HEADER, EMPTY) <= 160):toBeTruthy()
	end)

	T.it("tiles spans so adjacent blocks meet with exactly one gap", function()
		local unit = ShopLayout.trackUnit(1046, TRACKS, GAP)
		local wide = ShopLayout.spanWidth(unit, 8, GAP)
		local narrow = ShopLayout.spanWidth(unit, 4, GAP)
		T.expect(wide + GAP + narrow):toEqual(1046)
		T.expect(ShopLayout.spanWidth(unit, 12, GAP)):toEqual(1046)
		T.expect(ShopLayout.trackOffset(unit, 8)):toEqual(wide + GAP)
		-- Width is a function of the span alone so a block can be measured before
		-- it is placed, which leaves two quarter spans up to a pixel short of the
		-- half span they sit under. That is the whole error budget of the grid.
		T.expect(narrow + GAP + narrow):toBeNear(wide, 1)
	end)

	T.it("asks a column for one card alone but two once a block holds more", function()
		T.expect(ShopLayout.minColumnWidth(1, CLASSES.Promo, CARD_GAP)):toEqual(210)
		T.expect(ShopLayout.minColumnWidth(3, CLASSES.Feature, CARD_GAP)):toEqual(312)
		T.expect(ShopLayout.minColumnWidth(9, CLASSES.Feature, CARD_GAP)):toEqual(312)
	end)

	T.it("keeps configured spans at desktop widths and widens them on a phone", function()
		local desktop = ShopLayout.trackUnit(1046, TRACKS, GAP)
		local crates = ShopLayout.minColumnWidth(3, CLASSES.Feature, CARD_GAP)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, desktop, GAP, crates)):toEqual(4)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, desktop, GAP, CLASSES.Promo.MinPx)):toEqual(4)

		-- A 720p window is the narrowest the dashboard is meant to survive.
		local laptop = ShopLayout.trackUnit(741, TRACKS, GAP)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, laptop, GAP, CLASSES.Feature.MinPx)):toEqual(4)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, laptop, GAP, CLASSES.Promo.MinPx)):toEqual(4)

		local phone = ShopLayout.trackUnit(288, TRACKS, GAP)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, phone, GAP, crates)):toEqual(12)
		T.expect(
			ShopLayout.resolveSpan(8, STEPS, TRACKS, phone, GAP, ShopLayout.minColumnWidth(4, CLASSES.Tile, CARD_GAP))
		)
			:toEqual(12)
	end)

	T.it("starts a block under the shorter neighbour instead of the taller one", function()
		-- Passes across the top, then a wide currency block beside a narrow crate
		-- block that wraps to twice its height. The offers that follow must begin
		-- under the currency block, not wait for the crates to finish.
		local placements = ShopLayout.place({
			block("passes", 12, 100),
			block("bonks", 8, 100),
			block("crates", 4, 300),
			block("weekly", 4, 80),
			block("featured", 4, 80),
		}, TRACKS, 0)
		local at = placedBy(placements)

		T.expect(at.bonks.index):toEqual(0)
		T.expect(at.crates.index):toEqual(8)
		T.expect(at.crates.y):toEqual(at.bonks.y)

		local underBonks = at.bonks.y + 100
		T.expect(at.weekly.y):toEqual(underBonks)
		T.expect(at.featured.y):toEqual(underBonks)
		T.expect(at.weekly.index):toEqual(0)
		T.expect(at.featured.index):toEqual(4)
		T.expect(overlaps(placements)):toEqual(false)
	end)

	T.it("prefers the position that buries the least empty space on a tie", function()
		-- Both halves are free at the same height, but only the right one is
		-- level: a block placed on the left would strand the gap beneath it.
		local placements = ShopLayout.place({
			block("top", 12, 100),
			block("left", 4, 200),
			block("right", 8, 100),
			block("next", 8, 100),
		}, TRACKS, 0)
		local at = placedBy(placements)
		T.expect(at.left.index):toEqual(0)
		T.expect(at.right.index):toEqual(4)
		T.expect(at.next.index):toEqual(4)
		T.expect(at.next.y):toEqual(200)
		T.expect(overlaps(placements)):toEqual(false)
	end)

	T.it("reports the true extent of everything it placed", function()
		local placements, bottom = ShopLayout.place({
			block("a", 8, 100),
			block("b", 4, 260),
			block("c", 8, 100),
		}, TRACKS, 10)
		T.expect(bottom):toEqual(260)
		T.expect(placedBy(placements).c.y):toEqual(110)
		T.expect(overlaps(placements)):toEqual(false)
	end)

	T.it("reuses space beneath a short offer after a wide section bridges it", function()
		local placements, bottom = ShopLayout.place({
			block("passes", 12, 100),
			block("featured", 4, 80),
			block("crates", 8, 320),
			block("bonks", 12, 60),
			block("overflow", 4, 180),
		}, TRACKS, GAP)
		local at = placedBy(placements)
		T.expect(at.overflow.index):toEqual(0)
		T.expect(at.overflow.y):toEqual(at.featured.y + 80 + GAP)
		T.expect(at.overflow.y + 180 + GAP <= at.bonks.y):toBeTruthy()
		T.expect(bottom):toEqual(520)
		T.expect(overlaps(placements, GAP)):toEqual(false)
	end)

	T.it("compacts secondary sections while preserving the featured three-column row", function()
		local bonks = block("bonks", 8, 190)
		bonks.alternatives = { block("bonks", 4, 380) }
		local entries = {
			block("passes", 12, 100),
			block("featured", 4, 150),
			block("crates", 4, 420),
			bonks,
			block("forYou", 4, 420),
			block("more", 8, 210),
		}
		local _, originalBottom = ShopLayout.place(entries, TRACKS, GAP)
		local placements, bottom = ShopLayout.compact(entries, TRACKS, GAP)
		local at = placedBy(placements)
		T.expect(at.featured.index):toEqual(0)
		T.expect(at.crates.index):toEqual(4)
		T.expect(at.forYou.index):toEqual(8)
		T.expect(at.featured.y):toEqual(at.crates.y)
		T.expect(at.forYou.y):toEqual(at.crates.y)
		T.expect(at.bonks.span):toEqual(4)
		T.expect(at.bonks.y):toEqual(at.featured.y + 150 + GAP)
		T.expect(at.more.index):toEqual(4)
		T.expect(bottom < originalBottom):toBeTruthy()
		T.expect(overlaps(placements, GAP)):toEqual(false)
	end)

	T.it("keeps a wide section when narrowing it would make it finish later", function()
		local bonks = block("bonks", 8, 190)
		bonks.alternatives = { block("bonks", 4, 1000) }
		local placements = ShopLayout.compact({
			block("passes", 12, 100),
			block("featured", 4, 150),
			block("crates", 4, 420),
			bonks,
			block("forYou", 4, 420),
		}, TRACKS, GAP)
		T.expect(placedBy(placements).bonks.span):toEqual(8)
		T.expect(overlaps(placements, GAP)):toEqual(false)
	end)

	T.it("fits sparse pass overflow under the featured offer", function()
		local more = block("more", 8, 210)
		more.alternatives = { block("more", 4, 210) }
		local placements = ShopLayout.compact({
			block("passes", 12, 100),
			block("featured", 4, 150),
			block("crates", 4, 420),
			block("bonks", 8, 190),
			block("forYou", 4, 420),
			more,
		}, TRACKS, GAP)
		local at = placedBy(placements)
		T.expect(at.more.span):toEqual(4)
		T.expect(at.more.index):toEqual(0)
		T.expect(at.more.y):toEqual(at.featured.y + 150 + GAP)
		T.expect(overlaps(placements, GAP)):toEqual(false)
	end)

	T.it("does not reserve unused card columns for a single overflow pass", function()
		local unit = ShopLayout.trackUnit(1046, TRACKS, GAP)
		local wide = block("more", 8, 0)
		local narrow = block("more", 4, 0)
		for _, entry in { wide, narrow } do
			local width = ShopLayout.spanWidth(unit, entry.span, GAP)
			local grid = ShopLayout.grid(width, 1, CLASSES.Pass, CARD_GAP, 4)
			entry.height = ShopLayout.sectionHeight(grid, HEADER, EMPTY)
			entry.unusedWidth = width - grid.cardWidth
		end
		wide.alternatives = { narrow }
		local placements = ShopLayout.compact({ block("passes", TRACKS, 290), wide }, TRACKS, GAP)
		T.expect(placedBy(placements).more.span):toEqual(4)
		T.expect(overlaps(placements, GAP)):toEqual(false)
	end)

	T.it("keeps the full-width phone composition without gaps or overlap", function()
		for _, available in { 288, 460 } do
			local entries = {}
			for _, spec in { { "Pass", 2 }, { "Promo", 1 }, { "Feature", 3 }, { "Tile", 4 }, { "Feature", 3 } } do
				local grid = ShopLayout.grid(available, spec[2], CLASSES[spec[1]], CARD_GAP, 4)
				table.insert(
					entries,
					block(`section{#entries + 1}`, TRACKS, ShopLayout.sectionHeight(grid, HEADER, EMPTY))
				)
			end
			local placements, bottom = ShopLayout.compact(entries, TRACKS, GAP)
			local expected = 0
			for _, placement in placements do
				T.expect(placement.span):toEqual(TRACKS)
				T.expect(placement.index):toEqual(0)
				T.expect(placement.y):toEqual(expected)
				expected += placement.block.height + GAP
			end
			T.expect(bottom):toEqual(expected - GAP)
			T.expect(overlaps(placements, GAP)):toEqual(false)
		end
	end)

	T.it("keeps later importance bands below the dynamic catalog", function()
		local passes = block("passes", 12, 100)
		passes.priority = 1
		local crates = block("crates", 4, 260)
		crates.priority = 2
		local forYou = block("forYou", 4, 420)
		forYou.priority = 2
		local bonks = block("bonks", 8, 190)
		bonks.priority = 2
		local misc = block("misc", 4, 80)
		misc.priority = 3

		local placements = ShopLayout.compact({ passes, crates, forYou, bonks, misc }, TRACKS, GAP)
		local at = placedBy(placements)
		T.expect(at.crates.y):toEqual(at.passes.y + passes.height + GAP)
		T.expect(at.forYou.y):toEqual(at.crates.y)
		T.expect(at.bonks.y >= at.crates.y):toBeTruthy()
		T.expect(at.misc.y > at.bonks.y):toBeTruthy()
		T.expect(overlaps(placements, GAP)):toEqual(false)
	end)

	T.it("never overlaps blocks whatever order and spans it is handed", function()
		local spans = { 12, 4, 8, 4, 4, 8, 4, 12, 4 }
		local blocks = {}
		for index, span in spans do
			table.insert(blocks, block(`b{index}`, span, 40 + index * 37 % 190))
		end
		local placements, bottom = ShopLayout.place(blocks, TRACKS, 14)
		T.expect(#placements):toEqual(#spans)
		T.expect(overlaps(placements)):toEqual(false)
		T.expect(bottom > 0):toBeTruthy()
	end)
end)

return true
