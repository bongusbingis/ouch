--!strict

local T = require(script.Parent.TestKit)
local ShopLayout = require(script.Parent.Parent.UI.Models.ShopLayout)

-- Mirrors Config.Interface.UI.Layout.Shop, which cannot be required headlessly
-- because it builds Font values.
local CARD_GAP = 12
local GAP = 20
local TRACKS = 12
local STEPS = { 4, 8, 12 }
local HEADER = 26
local EMPTY = 54
local CLASSES = {
	Pass = { MinPx = 130, MaxPx = 300, Aspect = 0.78, MinHeightPx = 176 },
	Tile = { MinPx = 100, MaxPx = 200, Aspect = 1.04, MinHeightPx = 112 },
	Feature = { MinPx = 100, MaxPx = 235, Aspect = 0.68, MinHeightPx = 118 },
	Promo = { MinPx = 210, MaxPx = 560, Aspect = 0.44, MinHeightPx = 118 },
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

local function overlaps(placements): boolean
	for i = 1, #placements do
		for j = i + 1, #placements do
			local a, b = placements[i], placements[j]
			local sameTracks = a.index < b.index + b.span and b.index < a.index + a.span
			local aBottom = a.y + a.block.height
			local bBottom = b.y + b.block.height
			local sameRows = a.y < bBottom and b.y < aBottom
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
		T.expect(ShopLayout.minColumnWidth(3, CLASSES.Feature, CARD_GAP)):toEqual(212)
		T.expect(ShopLayout.minColumnWidth(9, CLASSES.Feature, CARD_GAP)):toEqual(212)
	end)

	T.it("keeps configured spans at desktop widths and widens them on a phone", function()
		local desktop = ShopLayout.trackUnit(1046, TRACKS, GAP)
		local crates = ShopLayout.minColumnWidth(3, CLASSES.Feature, CARD_GAP)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, desktop, GAP, crates)):toEqual(4)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, desktop, GAP, CLASSES.Promo.MinPx)):toEqual(4)

		-- A 720p window is the narrowest the dashboard is meant to survive.
		local laptop = ShopLayout.trackUnit(741, TRACKS, GAP)
		T.expect(ShopLayout.resolveSpan(4, STEPS, TRACKS, laptop, GAP, crates)):toEqual(4)
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
