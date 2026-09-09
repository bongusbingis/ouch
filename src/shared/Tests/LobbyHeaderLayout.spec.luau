--!strict

local T = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.LobbyHeaderLayout)

local function expectControlsInside(layout, width: number)
	for _, rect in { layout.nav, layout.party } do
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
		T.expect(layout.logo.size.X):toEqual(220)
		T.expect(layout.logo.size.Y):toEqual(100)
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

return true
