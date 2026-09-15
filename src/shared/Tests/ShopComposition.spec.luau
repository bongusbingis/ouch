--!strict
local T = require(script.Parent.TestKit)
local Composition = require(script.Parent.Parent.UI.Models.ShopComposition)
local Summary = require(script.Parent.Parent.UI.Models.CrateOddsSummary)
local Layout = require(script.Parent.Parent.UI.Models.ShopLayout)
local CandyConfig = require(script.Parent.Parent.UI.Models.CandyShopConfig)
local ShopTokens = require(script.Parent.Parent.UI.Tokens).Shop
local ShapeTokens = require(script.Parent.Parent.UI.Tokens).Shape

local function catalogGrid(width, count, className, maxColumns, short)
	local class = CandyConfig.CardClasses[className]
	if short then
		class = Composition.shortClass(class, ShopTokens.PromoMin, ShopTokens.ShortCardHeight)
	end
	local grid = Layout.grid(width, count, class, CandyConfig.CardGapPx, maxColumns)
	class = Composition.adaptiveClass(
		class,
		grid.cardWidth,
		ShopTokens.CatalogSplitMin,
		ShopTokens.CatalogSplitHeight,
		ShopTokens.PromoMin,
		ShopTokens.CardHeight
	)
	return Layout.grid(width, count, class, CandyConfig.CardGapPx, maxColumns), class
end
local config = {
	Sections = { More = { Class = "Pass", Span = 8 }, ForYou = { Class = "Feature", Span = 4 } },
	DefaultSection = { Class = "Feature", Span = 4 },
	Order = { "More", "ForYou" },
}
T.describe("Candy shop composition", function()
	T.it("reserves separate title, countdown and card bands in narrow headers", function()
		T.expect(CandyConfig.HeaderHeight(348, nil, false)):toEqual(58)
		T.expect(CandyConfig.HeaderHeight(348, 100, true)):toEqual(42)
		T.expect(CandyConfig.HeaderHeight(300, 100, false)):toEqual(58)
		for _, short in { false, true } do
			local height = CandyConfig.HeaderHeight(299, 100, short)
			local countdownTop = ShopTokens.CountdownTitleHeight + ShopTokens.SectionContentGap
			local countdownBottom = countdownTop + ShopTokens.CountdownHeight
			T.expect(height):toEqual(88)
			T.expect(countdownTop - ShopTokens.CountdownTitleHeight):toEqual(12)
			T.expect(height - countdownBottom):toEqual(12)
		end
	end)
	T.it("keeps decoration and outlined ownership chips visibly separated", function()
		T.expect(ShopTokens.SectionUnderlineGap):toEqual(6)
		T.expect(ShopTokens.SectionContentGap):toEqual(12)
		T.expect(ShopTokens.SectionContentGap - ShapeTokens.StrokeCard >= 8):toBeTruthy()
		T.expect(ShopTokens.BadgeGap - ShapeTokens.StrokeInner * 2 >= 8):toBeTruthy()
	end)
	T.it("fills the reduced shop's two lanes with shorter horizontal catalog cards", function()
		local width = 718
		local unit = Layout.trackUnit(width, CandyConfig.Tracks, CandyConfig.GapPx)
		for _, className in { "Pass", "Feature" } do
			local original = CandyConfig.CardClasses[className]
			local span =
				Composition.span(width, 4, original.MinPx, CandyConfig.GapPx, ShopTokens.WideMin, ShopTokens.MediumMin)
			local laneWidth = Layout.spanWidth(unit, span, CandyConfig.GapPx)
			local grid, class = catalogGrid(laneWidth, 3, className, 4)
			T.expect(span):toEqual(6)
			T.expect(grid.columns):toEqual(1)
			T.expect(grid.cardWidth):toEqual(348)
			T.expect(grid.cardHeight):toEqual(220)
			T.expect(grid.rows):toEqual(3)
			T.expect(grid.height):toEqual(696)
			T.expect(class.Layout):toEqual("Split")
			T.expect(original.Layout):toEqual("Stack")
			T.expect(original.MinHeightPx):toEqual(270)
		end
	end)
	T.it("fills a phone column while preserving stacked artwork and every offer", function()
		local grid, class = catalogGrid(284, 5, "Feature", 2)
		T.expect(grid.columns):toEqual(1)
		T.expect(grid.cardWidth):toEqual(284)
		T.expect(grid.cardHeight):toEqual(270)
		T.expect(grid.rows):toEqual(5)
		T.expect(class.Layout):toEqual("Stack")
	end)
	T.it("changes proportions only when the measured card has room for both columns", function()
		local below, belowClass = catalogGrid(319, 2, "Pass", 4)
		local at, atClass = catalogGrid(320, 2, "Pass", 4)
		T.expect(below.cardHeight):toEqual(270)
		T.expect(belowClass.Layout):toEqual("Stack")
		T.expect(at.cardHeight):toEqual(220)
		T.expect(atClass.Layout):toEqual("Split")
		local narrow, narrowClass = catalogGrid(386, 3, "Feature", 2)
		T.expect(narrow.columns):toEqual(2)
		T.expect(narrow.cardWidth):toEqual(184)
		T.expect(narrow.cardHeight):toEqual(270)
		T.expect(narrow.rows):toEqual(2)
		T.expect(narrowClass.Layout):toEqual("Stack")
	end)
	T.it("retains dense wide rows and the short landscape height", function()
		local wide, wideClass = catalogGrid(900, 5, "Pass", 4)
		T.expect(wide.columns):toEqual(4)
		T.expect(wide.cardWidth):toEqual(211)
		T.expect(wide.rows):toEqual(2)
		T.expect(wide.cardHeight):toEqual(270)
		T.expect(wideClass.Layout):toEqual("Stack")
		local short, shortClass = catalogGrid(348, 3, "Pass", 4, true)
		T.expect(short.cardWidth):toEqual(348)
		T.expect(short.cardHeight):toEqual(176)
		T.expect(short.rows):toEqual(3)
		T.expect(shortClass.Layout):toEqual("Split")
	end)
	T.it("preserves season, promotion and currency card proportions", function()
		for _, className in { "Season", "Promo", "Tile" } do
			local original = CandyConfig.CardClasses[className]
			local grid, class = catalogGrid(400, 1, className, 1)
			T.expect(class):toEqual(original)
			T.expect(grid.cardHeight):toEqual(original.MinHeightPx)
		end
	end)
	T.it("restores stacked height when a short window cannot fit split artwork and copy", function()
		local narrow, narrowClass = catalogGrid(279, 3, "Pass", 4, true)
		T.expect(narrow.cardWidth):toEqual(279)
		T.expect(narrow.cardHeight):toEqual(270)
		T.expect(narrowClass.Layout):toEqual("Stack")
		T.expect(narrow.rows):toEqual(3)
		local fitting, fittingClass = catalogGrid(280, 3, "Pass", 4, true)
		T.expect(fitting.cardHeight):toEqual(176)
		T.expect(fittingClass.Layout):toEqual("Split")
	end)
	T.it("reserves a full artwork band for currency cards below the split threshold", function()
		local narrow, narrowClass = catalogGrid(264, 4, "Tile", 3)
		local nameTop = narrow.cardHeight - ShopTokens.CardPadding * 2 - ShopTokens.ActionHeight - ShopTokens.NameHeight
		local artworkHeight = nameTop - ShopTokens.CardPadding - ShopTokens.ArtTop
		T.expect(narrow.cardHeight):toEqual(270)
		T.expect(narrowClass.Layout):toEqual("Stack")
		T.expect(narrow.rows):toEqual(4)
		T.expect(artworkHeight >= 28):toBeTruthy()
		local fitting, fittingClass = catalogGrid(280, 4, "Tile", 3)
		T.expect(fitting.cardHeight):toEqual(206)
		T.expect(fittingClass.Layout):toEqual("Split")
		T.expect(CandyConfig.CardClasses.Tile.MinHeightPx):toEqual(206)
	end)
	T.it("keeps compact card bounds valid when switching from a narrow showcase", function()
		local original = { MinPx = 184, MaxPx = 270, MinHeightPx = 270, Aspect = 1 }
		local compact = Composition.shortClass(original, 280, 160)
		local Layout = require(script.Parent.Parent.UI.Models.ShopLayout)
		local grid = Layout.grid(640, 4, compact, 18, 4)
		T.expect(grid.columns):toEqual(2)
		T.expect(grid.rows):toEqual(2)
		T.expect(grid.cardHeight):toEqual(160)
		T.expect(original.MinPx):toEqual(184)
		T.expect(original.MaxPx):toEqual(270)
	end)
	T.it("promotes an owned season once without mutating the catalog", function()
		local season = { id = "season", kind = "SeasonPass", owned = true }
		local pass = { id = "pass", kind = "GamePass" }
		local model = {
			sections = { { id = "More", title = "Passes", cards = { pass, season } } },
			hero = {
				{ id = "promo", kind = "Crate" },
			},
		}
		local featured, catalog = Composition.groups(model, config)
		T.expect(featured[1].cards[1]):toEqual(season)
		T.expect(#featured):toEqual(2)
		T.expect(#catalog[1].cards):toEqual(1)
		T.expect(catalog[1].cards[1]):toEqual(pass)
		T.expect(#model.sections[1].cards):toEqual(2)
	end)
	T.it("expands a solitary promotion and retains unknown sections", function()
		local featured, catalog = Composition.groups({
			sections = { { id = "Future", title = "Future", cards = { { id = "x" } } } },
			hero = {
				{ id = "promo", kind = "Bundle" },
			},
		}, config)
		T.expect(featured[1].style.Span):toEqual(12)
		T.expect(catalog[1].id):toEqual("Future")
	end)
	T.it("removes empty sections without losing any real cards", function()
		local featured, catalog = Composition.groups({
			sections = {
				{ id = "More", cards = {} },
				{ id = "ForYou", cards = { { id = "a" }, { id = "b" }, { id = "c" } } },
			},
			hero = {},
		}, config)
		T.expect(#featured):toEqual(0)
		T.expect(#catalog):toEqual(1)
		T.expect(#catalog[1].cards):toEqual(3)
	end)
	T.it("uses two lanes at medium width and lets only a demanding block span both", function()
		T.expect(Composition.span(700, 4, 184, 22, 920, 560)):toEqual(6)
		T.expect(Composition.span(700, 8, 360, 22, 920, 560)):toEqual(12)
		T.expect(Composition.span(350, 4, 184, 22, 920, 560)):toEqual(12)
		T.expect(Composition.span(1200, 4, 184, 22, 920, 560)):toEqual(4)
	end)
	T.it("does not present unequal odds or refunds as a shared value", function()
		local chance, base, refund = Summary.shared({
			{ percent = 10, basePercent = 5, bonksRefund = 50 },
			{ percent = 15, basePercent = 5, bonksRefund = 100 },
		})
		T.expect(chance):toEqual(nil)
		T.expect(base):toEqual(5)
		T.expect(refund):toEqual(nil)
	end)
	T.it("summarizes identical outcomes and handles empty groups", function()
		local chance, base, refund = Summary.shared({
			{ percent = 10, basePercent = 5, bonksRefund = 50 },
			{ percent = 10, basePercent = 5, bonksRefund = 50 },
		})
		T.expect(chance):toEqual(10)
		T.expect(base):toEqual(5)
		T.expect(refund):toEqual(50)
		T.expect(Summary.shared({})):toEqual(nil)
	end)
end)
return true
