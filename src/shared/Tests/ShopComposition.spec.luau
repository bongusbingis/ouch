--!strict
local T = require(script.Parent.TestKit)
local Composition = require(script.Parent.Parent.UI.Models.ShopComposition)
local Summary = require(script.Parent.Parent.UI.Models.CrateOddsSummary)
local config = {
	Sections = { More = { Class = "Pass", Span = 8 }, ForYou = { Class = "Feature", Span = 4 } },
	DefaultSection = { Class = "Feature", Span = 4 },
	Order = { "More", "ForYou" },
}
T.describe("Candy shop composition", function()
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
