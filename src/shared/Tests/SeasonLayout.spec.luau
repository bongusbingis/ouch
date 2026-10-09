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
	T.it("fits the short-landscape reward preview stack inside its well", function()
		local measures = {
			-- Realistic chips: "PREMIUM • TIER 12" / "PREMIUM PASS + TIER 12" / "HAT".
			{ track = 190, requirement = 240, kind = 40 },
			-- Longest requirement copy: shares the kind row when the track row is full.
			{ track = 190, requirement = 340, kind = 90 },
			-- Nothing shares a row: the requirement takes the kind caption's place.
			{ track = 190, requirement = 560, kind = 90 },
		}
		local modes = {}
		for _, size in { Vector2.new(750, 304), Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(960, 540) } do
			for _, premium in { false, true } do
				local layout = Layout.resolve(size, premium)
				T.expect(layout.short):toBeTruthy()
				for _, measure in measures do
					local stack = Layout.shortPreview(layout.bodyHeight, layout.previewWidth, measure)
					if size.X == 750 and size.Y == 304 then
						modes[stack.mode] = true
					end
					local h = layout.bodyHeight
					T.expect(stack.top >= 0 and stack.top + stack.total <= h):toBeTruthy()
					T.expect(stack.back.size >= 44 and stack.back.y + stack.back.size <= h):toBeTruthy()
					T.expect(stack.face.y >= 0 and stack.face.y + stack.face.side <= h):toBeTruthy()
					T.expect(stack.name.y >= stack.back.y + stack.back.size):toBeTruthy()
					local nameBottom = stack.name.y + stack.name.height
					local kindBottom = nameBottom
					if stack.kind then
						T.expect(stack.kind.y >= nameBottom):toBeTruthy()
						kindBottom = stack.kind.y + stack.kind.height
						T.expect(kindBottom <= h):toBeTruthy()
					end
					local r = stack.requirement
					T.expect(r.y >= 0 and r.y + r.height <= h):toBeTruthy()
					T.expect(r.x >= stack.columnX and r.x + r.width <= stack.columnX + stack.columnWidth):toBeTruthy()
					if stack.mode == "TrackRow" then
						T.expect(r.x >= stack.track.x + math.min(measure.track, stack.track.maxWidth)):toBeTruthy()
					elseif stack.mode == "KindRow" then
						T.expect(r.y):toEqual(stack.kind.y)
						T.expect(r.x >= stack.columnX + stack.kind.width):toBeTruthy()
					else
						T.expect(r.y >= kindBottom):toBeTruthy()
					end
				end
			end
		end
		-- 750x304 leaves a 126 px well: the roomy two-line stack never applies there.
		T.expect(Layout.resolve(Vector2.new(750, 304), false).bodyHeight):toEqual(126)
		T.expect(modes.Stacked):toEqual(nil)
		T.expect(modes.TrackRow and modes.KindRow and modes.NoKind):toBeTruthy()
	end)
end)
return true
