-- Description: Spec for training throw steering: that a ball turns toward a target it is already aimed near, keeps its speed, refuses targets outside the cone or out of range, and never overshoots the target heading.

--!strict

local T = require(script.Parent.TestKit)
local OnboardingAssist = require(script.Parent.Parent.Game.Onboarding.OnboardingAssist)

local ORIGIN = vector.zero
local WIDE = math.cos(math.rad(80))
local FAR = 500

local function steer(velocity, target, turn, cone, range)
	return OnboardingAssist.steer(ORIGIN, velocity, target, turn, cone or WIDE, range or FAR)
end

T.describe("OnboardingAssist", function()
	T.it("turns a throw toward a target off to one side", function()
		local steered = steer(vector.create(0, 0, -100), vector.create(30, 0, -100), math.rad(20))
		T.expect(steered ~= nil):toEqual(true)
		T.expect((steered :: any).x > 0):toEqual(true)
	end)

	T.it("preserves speed exactly so steering never slows a throw", function()
		local steered = steer(vector.create(0, 0, -100), vector.create(40, 0, -90), math.rad(15))
		T.expect(vector.magnitude(steered :: any)):toBeNear(100, 1e-3)
	end)

	T.it("never turns further than the target heading", function()
		local target = vector.create(10, 0, -100)
		local steered = steer(vector.create(0, 0, -100), target, math.rad(90))
		local desired = vector.normalize(target)
		local heading = vector.normalize(steered :: any)
		T.expect(vector.dot(heading, desired)):toBeNear(1, 1e-4)
	end)

	T.it("leaves a throw alone once it is already dead on", function()
		T.expect(steer(vector.create(0, 0, -100), vector.create(0, 0, -50), math.rad(20))):toBeNil()
	end)

	T.it("refuses a target outside the acquisition cone", function()
		local narrow = math.cos(math.rad(20))
		T.expect(steer(vector.create(0, 0, -100), vector.create(100, 0, -30), math.rad(20), narrow)):toBeNil()
	end)

	T.it("refuses a target behind the ball", function()
		T.expect(steer(vector.create(0, 0, -100), vector.create(0, 0, 60), math.rad(20))):toBeNil()
	end)

	T.it("refuses a target beyond range", function()
		T.expect(steer(vector.create(0, 0, -100), vector.create(0, 0, -400), math.rad(20), WIDE, 100)):toBeNil()
	end)

	T.it("leaves a stationary ball and a zero turn rate alone", function()
		T.expect(steer(vector.zero, vector.create(0, 0, -50), math.rad(20))):toBeNil()
		T.expect(steer(vector.create(0, 0, -100), vector.create(20, 0, -80), 0)):toBeNil()
	end)

	T.it("turns by no more than the rate allows in one tick", function()
		local steered = steer(vector.create(0, 0, -100), vector.create(100, 0, -100), math.rad(5))
		local heading = vector.normalize(steered :: any)
		T.expect(math.deg(math.acos(math.clamp(vector.dot(heading, vector.create(0, 0, -1)), -1, 1)))):toBeNear(5, 1e-3)
	end)
end)

return true
