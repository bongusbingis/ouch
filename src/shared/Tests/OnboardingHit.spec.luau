-- Name: OnboardingHit.spec.luau
-- Author: Jack C.
-- Description: Spec for the training hit predicates: that the hammer cone matches the real weapon's reach, spread and vertical band, and that a thrown ball is caught by the segment it swept rather than only where it happened to be sampled.
-- Created: 2026-08-26

--!strict

local T = require(script.Parent.TestKit)
local OnboardingHit = require(script.Parent.Parent.Game.Onboarding.OnboardingHit)

local CONE = { Range = 7, Width = 4, Height = 5 }
local FORWARD = vector.create(0, 0, -1)
local ORIGIN = vector.zero

local function cone(target: Vector3, radius: number?)
	return OnboardingHit.withinHammerCone(ORIGIN, FORWARD, target, radius or 0, CONE)
end

T.describe("OnboardingHit", function()
	T.describe("hammer cone", function()
		T.it("hits a target straight ahead inside range", function()
			T.expect(cone(vector.create(0, 0, -5))):toEqual(true)
		end)

		T.it("misses a target beyond range", function()
			T.expect(cone(vector.create(0, 0, -9))):toEqual(false)
		end)

		T.it("misses a target directly behind", function()
			T.expect(cone(vector.create(0, 0, 5))):toEqual(false)
		end)

		T.it("extends reach and spread by the target's own radius", function()
			T.expect(cone(vector.create(0, 0, -9))):toEqual(false)
			T.expect(cone(vector.create(0, 0, -9), 3)):toEqual(true)
			T.expect(cone(vector.create(3, 0, -5))):toEqual(false)
			T.expect(cone(vector.create(3, 0, -5), 2)):toEqual(true)
		end)

		T.it("rejects a target outside the lateral spread", function()
			T.expect(cone(vector.create(1.9, 0, -5))):toEqual(true)
			T.expect(cone(vector.create(2.1, 0, -5))):toEqual(false)
		end)

		T.it("rejects a target outside the vertical band", function()
			T.expect(cone(vector.create(0, 2.4, -5))):toEqual(true)
			T.expect(cone(vector.create(0, 2.6, -5))):toEqual(false)
		end)

		T.it("treats a degenerate aim direction as no swing", function()
			T.expect(OnboardingHit.withinHammerCone(ORIGIN, vector.zero, vector.create(0, 0, -3), 2, CONE))
				:toEqual(false)
		end)

		T.it("does not require a normalized direction", function()
			local scaled = vector.create(0, 0, -12)
			T.expect(OnboardingHit.withinHammerCone(ORIGIN, scaled, vector.create(0, 0, -5), 0, CONE)):toEqual(true)
		end)
	end)

	T.describe("ball contact", function()
		T.it("counts a ball resting inside the radius", function()
			local at = vector.create(0, 0, -10)
			T.expect(OnboardingHit.ballReachedTarget(at, at, vector.create(0, 0, -11), 3)):toEqual(true)
		end)

		T.it("ignores a ball that stayed outside the radius", function()
			local at = vector.create(0, 0, -10)
			T.expect(OnboardingHit.ballReachedTarget(at, at, vector.create(0, 0, -20), 3)):toEqual(false)
		end)

		T.it("catches a fast ball that tunneled past the target between samples", function()
			local from = vector.create(0, 0, 0)
			local to = vector.create(0, 0, -40)
			T.expect(OnboardingHit.ballReachedTarget(from, to, vector.create(0, 0, -20), 2)):toEqual(true)
		end)

		T.it("does not count a target beside the swept segment", function()
			local from = vector.create(0, 0, 0)
			local to = vector.create(0, 0, -40)
			T.expect(OnboardingHit.ballReachedTarget(from, to, vector.create(9, 0, -20), 2)):toEqual(false)
		end)

		T.it("does not count a target behind the start of the segment", function()
			local from = vector.create(0, 0, 0)
			local to = vector.create(0, 0, -40)
			T.expect(OnboardingHit.ballReachedTarget(from, to, vector.create(0, 0, 8), 2)):toEqual(false)
		end)
	end)
end)

return true
