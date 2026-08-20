--!strict

local T = require(script.Parent.TestKit)
local Zones = require(script.Parent.Parent.Game.Input.Zones)

T.describe("Zones", function()
	T.it("splits the screen with movement on the left by default", function()
		local layout = Zones.layout(0.4, false)
		T.expect(layout.Movement.x):toBeNear(0, 1e-6)
		T.expect(layout.Movement.width):toBeNear(0.4, 1e-6)
		T.expect(layout.Action.x):toBeNear(0.4, 1e-6)
		T.expect(layout.Action.width):toBeNear(0.6, 1e-6)
	end)

	T.it("mirrors both zones for left-handed players", function()
		local layout = Zones.layout(0.4, true)
		T.expect(layout.Movement.x):toBeNear(0.6, 1e-6)
		T.expect(layout.Action.x):toBeNear(0, 1e-6)
		-- Widths are unchanged; only the sides swap.
		T.expect(layout.Movement.width):toBeNear(0.4, 1e-6)
		T.expect(layout.Action.width):toBeNear(0.6, 1e-6)
	end)

	T.it("covers the whole width with no gap or overlap", function()
		for _, leftHanded in { false, true } do
			local layout = Zones.layout(0.4, leftHanded)
			local covered = layout.Movement.width + layout.Action.width
			T.expect(covered):toBeNear(1, 1e-6)
			T.expect(Zones.contains(layout.Movement, 0.2, 0.5) ~= Zones.contains(layout.Action, 0.2, 0.5)):toBeTruthy()
		end
	end)

	T.it("treats a rect as half-open so adjacent zones never both claim a point", function()
		local layout = Zones.layout(0.4, false)
		T.expect(Zones.contains(layout.Movement, 0.4, 0.5)):toEqual(false)
		T.expect(Zones.contains(layout.Action, 0.4, 0.5)):toEqual(true)
	end)

	T.it("converts to pixels inside the usable area below the inset", function()
		local rect = Zones.toPixels({ x = 0, y = 0, width = 0.5, height = 1 }, 1000, 800, 0, 36)
		T.expect(rect.x):toBeNear(0, 1e-6)
		T.expect(rect.y):toBeNear(36, 1e-6)
		T.expect(rect.width):toBeNear(500, 1e-6)
		-- Height is the viewport minus the topbar, not the raw viewport.
		T.expect(rect.height):toBeNear(764, 1e-6)
	end)

	T.it("normalizes a touch against the same usable area", function()
		local x, y = Zones.normalize(500, 418, 1000, 800, 0, 36)
		T.expect(x):toBeNear(0.5, 1e-6)
		T.expect(y):toBeNear(0.5, 1e-6)
	end)

	T.it("rejects a point under the topbar", function()
		local x = Zones.normalize(500, 10, 1000, 800, 0, 36)
		T.expect(x):toBeNil()
	end)

	T.it("honours registered exclusion rects", function()
		local rects = { { x = 0.8, y = 0.8, width = 0.2, height = 0.2 } }
		T.expect(Zones.excluded(rects, 0.9, 0.9)):toBeTruthy()
		T.expect(Zones.excluded(rects, 0.5, 0.5)):toEqual(false)
		T.expect(Zones.excluded({}, 0.9, 0.9)):toEqual(false)
	end)

	T.it("scales pixel thresholds by viewport height", function()
		T.expect(Zones.scalePixels(12, 1080, 1080)):toBeNear(12, 1e-6)
		-- A shorter screen asks for proportionally less travel.
		T.expect(Zones.scalePixels(12, 540, 1080)):toBeNear(6, 1e-6)
	end)
end)

return true
