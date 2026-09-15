--!strict

local T = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.LobbyHeaderLayout)

local function expectControlsInside(layout, width: number)
	for _, rect in { layout.nav, layout.party, layout.logo } do
		T.expect(rect.position.X >= 0):toBeTruthy()
		T.expect(rect.position.X + rect.size.X <= width):toBeTruthy()
		T.expect(rect.position.Y >= 0):toBeTruthy()
		T.expect(rect.position.Y + rect.size.Y <= layout.height):toBeTruthy()
		T.expect(rect.size.Y >= 44):toBeTruthy()
	end
	T.expect(layout.buttonWidth >= 44):toBeTruthy()
end

T.describe("Lobby header composition", function()
	T.it("uses available phone width for the readable logo without expanding the camera reservation", function()
		local layout = Layout.resolve(Vector2.new(750, 344), 4)
		T.expect(layout.logo.size.Y):toEqual(64)
		T.expect(layout.logo.size.X):toEqual(220)
		T.expect(layout.height):toEqual(72)
		T.expect(layout.stacked):toBeFalsy()
		expectControlsInside(layout, 750)
		T.expect(layout.logo.position.X + layout.logo.size.X <= layout.nav.position.X):toBeTruthy()
		T.expect(layout.nav.position.X + layout.nav.size.X <= layout.party.position.X):toBeTruthy()
	end)

	T.it("reflows below the minimum single-row width instead of reducing navigation targets", function()
		local fitted = Layout.resolve(Vector2.new(562, 300), 4)
		local reflowed = Layout.resolve(Vector2.new(561, 300), 4)
		T.expect(fitted.stacked):toBeFalsy()
		T.expect(reflowed.stacked):toBeTruthy()
		T.expect(reflowed.buttonWidth):toEqual(fitted.buttonWidth)
		T.expect(reflowed.nav.position.Y >= reflowed.party.position.Y + reflowed.party.size.Y):toBeTruthy()
		T.expect(reflowed.height > fitted.height):toBeTruthy()
		expectControlsInside(fitted, 562)
		expectControlsInside(reflowed, 561)
	end)

	T.it("keeps a narrow landscape phone's party action distinct from all navigation targets", function()
		local layout = Layout.resolve(Vector2.new(480, 260), 4)
		expectControlsInside(layout, 480)
		T.expect(layout.partyLabel):toEqual("PARTY")
		T.expect(layout.party.position.Y + layout.party.size.Y <= layout.nav.position.Y):toBeTruthy()
	end)

	T.it("preserves the desktop header reservation with either supported tab count", function()
		for _, count in { 3, 4 } do
			local layout = Layout.resolve(Vector2.new(1246, 783), count)
			T.expect(layout.height):toEqual(88)
			T.expect(layout.partyLabel):toEqual("PARTY CODE")
			expectControlsInside(layout, 1246)
			T.expect(layout.logo.position.X + layout.logo.size.X <= layout.nav.position.X):toBeTruthy()
			T.expect(layout.nav.position.X + layout.nav.size.X <= layout.party.position.X):toBeTruthy()
		end
	end)
end)

local function mobileInsets(width: number, height: number, freeLeft: number, offset: Vector2?)
	local deviceOffset = offset or Vector2.new(0, 20)
	return {
		deviceOffset = deviceOffset,
		deviceSize = Vector2.new(width, height),
		coreOffset = deviceOffset + Vector2.new(0, 58),
		topbar = { Min = Vector2.new(freeLeft, 0), Max = Vector2.new(width, 58) },
	}
end

T.describe("Mobile lobby header", function()
	T.it("preserves the existing desktop composition", function()
		local size = Vector2.new(1246, 806)
		T.expect(Layout.resolveMobile(size, mobileInsets(size.X, size.Y, 208))):toEqual(nil)
		T.expect(Layout.resolve(size).height):toEqual(88)
	end)

	T.it("docks labeled landscape navigation on the CoreGui centerline", function()
		local insets = mobileInsets(750, 344, 208, Vector2.new(62, 20))
		local layout = Layout.resolveMobile(insets.deviceSize, insets, true)
		T.expect(layout.docked):toBeTruthy()
		T.expect(layout.iconOnly):toBeFalsy()
		T.expect(layout.nav.size):toEqual(Vector2.new(314, 56))
		T.expect(layout.nav.position.Y + layout.nav.size.Y / 2):toEqual(49)
		T.expect(layout.nav.position.X >= insets.deviceOffset.X + insets.topbar.Min.X + 6):toBeTruthy()
		T.expect(layout.emote.position.X >= layout.nav.position.X + layout.nav.size.X + 12):toBeTruthy()
		T.expect(layout.emote.position.X + layout.emote.size.X <= 806):toBeTruthy()
		T.expect(layout.emote.size):toEqual(Vector2.new(44, 44))
		T.expect(layout.bandHeight):toEqual(91)
		T.expect(layout.height):toEqual(13)
	end)

	T.it("uses four full touch targets beside CoreGui on a narrow portrait phone", function()
		local insets = mobileInsets(402, 816, 208)
		local layout = Layout.resolveMobile(insets.deviceSize, insets, true)
		T.expect(layout.docked):toBeTruthy()
		T.expect(layout.iconOnly):toBeTruthy()
		T.expect(layout.nav.size):toEqual(Vector2.new(176, 44))
		T.expect(layout.nav.position.Y + layout.nav.size.Y / 2):toEqual(49)
		T.expect(layout.nav.position.X >= 214):toBeTruthy()
		T.expect(layout.nav.position.X + layout.nav.size.X <= 396):toBeTruthy()
		T.expect(layout.emote):toEqual(nil)
		T.expect(layout.height):toEqual(17)
	end)

	T.it("prioritizes labels over an optional emote action", function()
		local insets = mobileInsets(534, 344, 208)
		local layout = Layout.resolveMobile(insets.deviceSize, insets, true)
		T.expect(layout.docked):toBeTruthy()
		T.expect(layout.iconOnly):toBeFalsy()
		T.expect(layout.emote):toEqual(nil)
		T.expect(layout.nav.size.X):toEqual(314)
	end)

	T.it("does not shrink icon targets to squeeze an undersized free row", function()
		local fits = mobileInsets(396, 700, 208)
		local tooNarrow = mobileInsets(395, 700, 208)
		T.expect(Layout.resolveMobile(fits.deviceSize, fits).docked):toBeTruthy()
		local fallback = Layout.resolveMobile(tooNarrow.deviceSize, tooNarrow)
		T.expect(fallback.docked):toBeFalsy()
		T.expect(fallback.iconOnly):toBeFalsy()
		T.expect(fallback.nav.position.Y):toEqual(tooNarrow.coreOffset.Y + 8)
		T.expect(fallback.nav.size.Y):toEqual(56)
	end)

	T.it("uses one contained labeled row when CoreGui leaves less than four targets", function()
		local insets = mobileInsets(320, 620, 208)
		local layout = Layout.resolveMobile(insets.deviceSize, insets, true)
		T.expect(layout.docked):toBeFalsy()
		T.expect(layout.nav.position.X):toEqual(6)
		T.expect(layout.nav.size):toEqual(Vector2.new(308, 56))
		T.expect(layout.height):toEqual(88)
		T.expect(layout.height < Layout.resolve(insets.deviceSize).height):toBeTruthy()
	end)

	T.it("uses mobile docking for a touch tablet without changing mouse desktop", function()
		local insets = mobileInsets(1200, 800, 208)
		T.expect(Layout.resolveMobile(insets.deviceSize, insets)):toEqual(nil)
		T.expect(Layout.resolveMobile(insets.deviceSize, insets, true).docked):toBeTruthy()
	end)

	T.it("does not attempt docking before a usable device rectangle exists", function()
		local insets = mobileInsets(1, 1, 208)
		T.expect(Layout.resolveMobile(insets.deviceSize, insets, true)):toEqual(nil)
	end)
end)

return true
