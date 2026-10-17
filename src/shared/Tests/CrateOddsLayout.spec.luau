--!strict
local Test = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.CrateOddsLayout)
local CollectibleLayout = require(script.Parent.Parent.UI.Models.CollectibleLayout)
local T = require(script.Parent.Parent.UI.Tokens)

Test.describe("Crate reward viewport clearance", function()
	Test.it("contains scaled outlines on both edges from compact to desktop widths", function()
		for width = 180, 720 do
			local layout = Layout.resolve(width)
			local overflowX = layout.tileWidth * (T.Motion.HoverScale - 1) / 2 + T.Shape.StrokeTab * T.Motion.HoverScale
			local overflowY = layout.tileHeight * (T.Motion.HoverScale - 1) / 2
				+ T.Shape.StrokeTab * T.Motion.HoverScale
			local right = layout.inset + layout.columns * layout.tileWidth + (layout.columns - 1) * layout.gap
			Test.expect(layout.inset >= overflowX and layout.inset >= overflowY):toBeTruthy()
			Test.expect(right + overflowX <= width):toBeTruthy()
			Test.expect(layout.tileWidth >= T.Layout.MinTarget):toBeTruthy()
			Test.expect(layout.tileHeight >= T.Layout.MinTarget):toBeTruthy()
			-- One hovered card must also clear its resting neighbour.
			Test.expect(layout.gap >= overflowX + T.Shape.StrokeTab):toBeTruthy()
		end
	end)
	Test.it("is short enough to show two rows yet keeps a usable collectible art window", function()
		local K = T.Collectible
		for _, width in { 200, 300, 500, 660 } do
			local layout = Layout.resolve(width)
			Test.expect(layout.tileHeight <= 190):toBeTruthy()
			local face = CollectibleLayout.card(
				layout.tileWidth,
				layout.tileHeight - T.Shape.LipHeight,
				{ tag = true, name = true, footer = true }
			)
			Test.expect(face.art.h >= 56):toBeTruthy()
			Test.expect(K.NameHeight >= 2 * 18):toBeTruthy()
		end
	end)
	Test.it("keeps multiple columns where full-size cards and their clearance fit", function()
		Test.expect(Layout.resolve(270).columns):toEqual(1)
		Test.expect(Layout.resolve(500).columns):toEqual(2)
		Test.expect(Layout.resolve(660).columns):toEqual(3)
	end)
	Test.it("reveals focused outlines at either viewport edge and respects canvas limits", function()
		Test.expect(Layout.reveal(212, 270, 12, 212, 400, 1000)):toEqual(200)
		Test.expect(Layout.reveal(212, 270, 12, 0, 400, 1000)):toEqual(94)
		Test.expect(Layout.reveal(212, 270, 12, 150, 400, 1000)):toEqual(150)
		Test.expect(Layout.reveal(0, 270, 12, 0, 400, 1000)):toEqual(0)
		Test.expect(Layout.reveal(730, 270, 12, 500, 400, 1000)):toEqual(600)
		-- A card taller than a short viewport remains reachable from its top.
		Test.expect(Layout.reveal(212, 270, 12, 0, 150, 1000)):toEqual(200)
	end)
end)

return true
