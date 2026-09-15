--!strict
local T = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.SeasonLayout)
local S = require(script.Parent.Parent.UI.Tokens).SeasonRewards

T.describe("Season reward composition", function()
	T.it("reserves separate progress, browser and reachable actions", function()
		for _, size in
			{
				Vector2.new(1246, 806),
				Vector2.new(1920, 1018),
				Vector2.new(402, 778),
				Vector2.new(750, 304),
				Vector2.new(960, 540),
			}
		do
			for _, premium in { false, true } do
				local layout = Layout.resolve(size, premium)
				T.expect(layout.statusTop + layout.statusHeight < layout.bodyTop):toBeTruthy()
				T.expect(layout.bodyTop + layout.bodyHeight < layout.footerTop):toBeTruthy()
				T.expect(layout.footerTop + layout.footerHeight <= layout.height - layout.inset):toBeTruthy()
				T.expect(layout.width < size.X and layout.height < size.Y):toBeTruthy()
				local browser = Layout.browser(layout.tracksWidth, layout.short)
				local cardArea = layout.bodyHeight - browser.cardsTop - browser.inset - S.ScrollPadding * 2
				T.expect(cardArea >= (if layout.short then 100 else S.CardHeight)):toBeTruthy()
			end
		end
	end)
	T.it("keeps track hitboxes separated and reward columns inside the scroll well", function()
		for _, width in { 318, 350, 550, 810 } do
			local browser = Layout.browser(width, false)
			T.expect(browser.tabHeight >= 44):toBeTruthy()
			T.expect(browser.tabWidth * 2 + S.TabGap <= width - browser.inset * 2):toBeTruthy()
			local used = browser.cardWidth * browser.columns
				+ S.CardGap * (browser.columns - 1)
				+ S.ScrollPadding * 2
				+ 6
			T.expect(used <= width - browser.inset * 2):toBeTruthy()
		end
	end)
	T.it("stacks purchase and claim actions only on narrow screens", function()
		T.expect(Layout.resolve(Vector2.new(402, 778), true).footerHeight >= 52 * 2 + 8):toBeTruthy()
		local desktop = Layout.resolve(Vector2.new(1246, 806), true)
		T.expect(desktop.previewWidth + desktop.gap + desktop.tracksWidth):toEqual(desktop.innerWidth)
		local phone = Layout.resolve(Vector2.new(750, 304), false)
		local browser = Layout.browser(phone.tracksWidth, true)
		T.expect(browser.cardsX > browser.tabWidth):toBeTruthy()
		T.expect(phone.bodyHeight >= browser.tabHeight * 2 + S.ShortGap):toBeTruthy()
	end)
end)
return true
