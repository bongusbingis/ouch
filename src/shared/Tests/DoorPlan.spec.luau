-- Name: DoorPlan.spec.luau
-- Author: Jack C.
-- Description: Spec for the door plan: exactly the configured number of distinct doors break per row, rows smaller than that break entirely, and the chooser decides which.
-- Created: 2026-09-14

--!strict

local T = require(script.Parent.TestKit)
local DoorPlan = require(script.Parent.Parent.Game.Splashdown.DoorPlan)

T.describe("DoorPlan", function()
	T.it("marks the configured number of distinct doors per row", function()
		local plan = DoorPlan.choose({ { "r1d1", "r1d2", "r1d3" }, { "r2d1", "r2d2", "r2d3" } }, 2, function()
			return 1
		end)
		T.expect(plan.r1d1):toEqual(true)
		T.expect(plan.r1d2):toEqual(true)
		T.expect(plan.r1d3):toBeNil()
		T.expect(plan.r2d1):toEqual(true)
		T.expect(plan.r2d2):toEqual(true)
		local count = 0
		for _ in plan do
			count += 1
		end
		T.expect(count):toEqual(4)
	end)

	T.it("breaks a whole row that is smaller than the quota and none when the quota is zero", function()
		local plan = DoorPlan.choose({ { "a" } }, 2, function()
			return 1
		end)
		T.expect(plan.a):toEqual(true)
		local none = DoorPlan.choose({ { "a", "b" } }, 0, function()
			return 1
		end)
		T.expect(next(none)):toBeNil()
	end)

	T.it("lets the chooser pick which doors break", function()
		local plan = DoorPlan.choose({ { "a", "b", "c" } }, 1, function(count)
			return count
		end)
		T.expect(plan.c):toEqual(true)
		T.expect(plan.a):toBeNil()
	end)
end)

return true
