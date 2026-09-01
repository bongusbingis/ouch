-- Name: Intercept.spec.luau
-- Author: Jack C.
-- Description: Spec for the interception maths: leading a crossing target, slower projectiles leading further, receding targets converging, motion consistency scoring, and clamped aim bias.
-- Created: 2026-08-19

--!strict

local T = require(script.Parent.TestKit)
local Intercept = require(script.Parent.Parent.Game.Sim.Intercept)

local function v(x: number, y: number, z: number)
	return vector.create(x, y, z)
end

T.describe("Intercept", function()
	T.it("returns the target's own position when it is not moving", function()
		local point = Intercept.solve(v(0, 0, 0), v(0, 0, 100), v(0, 0, 0), 200)
		T.expect(point.z):toBeNear(100, 1e-4)
		T.expect(point.x):toBeNear(0, 1e-4)
	end)

	T.it("leads a crossing target ahead of where it is now", function()
		local point = Intercept.solve(v(0, 0, 0), v(0, 0, 100), v(20, 0, 0), 200)
		T.expect(point.x > 9 and point.x < 11):toBeTruthy()
	end)

	T.it("leads further when the projectile is slower", function()
		local fast = Intercept.solve(v(0, 0, 0), v(0, 0, 100), v(20, 0, 0), 400)
		local slow = Intercept.solve(v(0, 0, 0), v(0, 0, 100), v(20, 0, 0), 100)
		T.expect(slow.x > fast.x):toBeTruthy()
	end)

	T.it("converges rather than running away on a receding target", function()
		local point = Intercept.solve(v(0, 0, 0), v(0, 0, 100), v(0, 0, 40), 200)
		T.expect(point.z > 100 and point.z < 140):toBeTruthy()
	end)

	T.it("degrades safely when the projectile has no speed", function()
		local point = Intercept.solve(v(0, 0, 0), v(0, 0, 100), v(20, 0, 0), 0)
		T.expect(point.z):toBeNear(100, 1e-4)
		T.expect(point.x):toBeNear(0, 1e-4)
	end)

	T.it("scores steady movement as consistent and reversals as not", function()
		local steady = { v(10, 0, 0), v(10, 0, 0), v(10, 0, 0) }
		local jittery = { v(10, 0, 0), v(-10, 0, 0), v(10, 0, 0) }
		T.expect(Intercept.consistency(steady)):toBeNear(1, 1e-6)
		T.expect(Intercept.consistency(jittery)):toBeNear(0, 1e-6)
	end)

	T.it("treats a stationary target as consistent, not unknown", function()
		T.expect(Intercept.consistency({ v(0, 0, 0), v(0, 0, 0) })):toBeNear(1, 1e-6)
	end)

	T.it("reports no confidence without enough samples", function()
		T.expect(Intercept.consistency({})):toEqual(0)
		T.expect(Intercept.consistency({ v(1, 0, 0) })):toEqual(0)
	end)

	T.it("leaves aim untouched at zero strength", function()
		local aim = v(0, 0, 1)
		local biased = Intercept.biasAim(aim, v(0, 0, 0), v(50, 0, 100), 0, math.rad(30))
		T.expect(biased.x):toBeNear(0, 1e-6)
		T.expect(biased.z):toBeNear(1, 1e-6)
	end)

	T.it("moves aim toward the intercept at full strength", function()
		local biased = Intercept.biasAim(v(0, 0, 1), v(0, 0, 0), v(50, 0, 100), 1, math.rad(60))
		T.expect(biased.x > 0):toBeTruthy()
		T.expect(vector.magnitude(biased)):toBeNear(1, 1e-5)
	end)

	T.it("never rotates further than the clamp allows", function()
		local biased = Intercept.biasAim(v(0, 0, 1), v(0, 0, 0), v(100, 0, 0), 1, math.rad(10))
		local angle = math.deg(math.acos(math.clamp(vector.dot(biased, v(0, 0, 1)), -1, 1)))
		T.expect(angle <= 10.5):toBeTruthy()
	end)

	T.it("scales the correction by strength", function()
		local half = Intercept.biasAim(v(0, 0, 1), v(0, 0, 0), v(100, 0, 100), 0.5, math.rad(90))
		local full = Intercept.biasAim(v(0, 0, 1), v(0, 0, 0), v(100, 0, 100), 1, math.rad(90))
		T.expect(full.x > half.x):toBeTruthy()
	end)
end)

return true
