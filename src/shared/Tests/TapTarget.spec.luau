--!strict

local T = require(script.Parent.TestKit)
local TapTarget = require(script.Parent.Parent.Game.Input.TapTarget)

local settings = {
	RadiusScale = 1.1,
	MinRadiusPixels = 44,
	MaxRadiusPixels = 220,
	WorldDistanceWeight = 0.25,
}

local function candidate(id: string, x: number, y: number, height: number, distance: number)
	return { id = id, screenX = x, screenY = y, apparentHeightPixels = height, worldDistance = distance }
end

T.describe("TapTarget", function()
	T.it("returns nothing when the tap lands near no one", function()
		local picked = TapTarget.pick({ candidate("a", 900, 900, 100, 50) }, 100, 100, 200, settings)
		T.expect(picked):toBeNil()
	end)

	T.it("picks the candidate nearest the finger", function()
		local candidates = { candidate("far", 140, 100, 100, 50), candidate("near", 105, 100, 100, 50) }
		T.expect(TapTarget.pick(candidates, 100, 100, 200, settings)):toEqual("near")
	end)

	T.it("scales the radius with apparent size", function()
		local big = candidate("big", 0, 0, 200, 10)
		local small = candidate("small", 0, 0, 10, 180)
		T.expect(TapTarget.radiusFor(big, settings)):toBeNear(220, 1e-6)
		-- Floored, so a tiny distant target stays tappable at all.
		T.expect(TapTarget.radiusFor(small, settings)):toBeNear(44, 1e-6)
	end)

	T.it("clamps the radius at both ends", function()
		local huge = candidate("huge", 0, 0, 10000, 5)
		T.expect(TapTarget.radiusFor(huge, settings)):toBeNear(settings.MaxRadiusPixels, 1e-6)
	end)

	T.it("prefers the closer enemy when two are equally near the finger", function()
		local candidates = { candidate("far", 120, 100, 100, 190), candidate("close", 120, 100, 100, 10) }
		T.expect(TapTarget.pick(candidates, 100, 100, 200, settings)):toEqual("close")
	end)

	T.it("still lets a clearly better tap beat a closer enemy", function()
		-- Dead on the far one, well off the near one: the finger wins.
		local candidates = { candidate("far", 100, 100, 100, 190), candidate("close", 200, 100, 100, 10) }
		T.expect(TapTarget.pick(candidates, 100, 100, 200, settings)):toEqual("far")
	end)

	T.it("handles an empty candidate list", function()
		T.expect(TapTarget.pick({}, 100, 100, 200, settings)):toBeNil()
	end)
end)

return true
