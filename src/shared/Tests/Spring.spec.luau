-- Description: Spec that the damped spring settles on its target and stays stable and finite across low frame rates and every frequency the game configures.

--!strict

local T = require(script.Parent.TestKit)
local Spring = require(script.Parent.Parent.Game.Util.Spring)

local function settle(frequency: number, damping: number, fps: number, seconds: number): number
	local spring = Spring.new(0)
	spring.target = 1
	for _ = 1, math.floor(fps * seconds) do
		Spring.step(spring, frequency, damping, 1 / fps)
	end
	return spring.position
end

T.describe("Spring", function()
	T.it("settles on its target at ordinary frame rates", function()
		T.expect(settle(9, 1, 60, 2)):toBeNear(1, 1e-3)
	end)

	T.it("stays stable at the frequencies the throw pose uses", function()
		T.expect(settle(14, 1, 60, 2)):toBeNear(1, 1e-3)
		T.expect(settle(11, 0.62, 60, 2)):toBeNear(1, 1e-3)
	end)

	T.it("stays stable on a slow client", function()
		for _, fps in { 30, 20, 15, 10 } do
			T.expect(settle(14, 1, fps, 3)):toBeNear(1, 1e-2)
		end
	end)

	T.it("stays stable at frequencies far above anything configured", function()
		T.expect(settle(40, 1, 60, 3)):toBeNear(1, 1e-2)
	end)

	T.it("never produces a non-finite position", function()
		local spring = Spring.new(0)
		spring.target = 1
		for _ = 1, 600 do
			Spring.step(spring, 30, 0.5, 1 / 30)
			T.expect(spring.position == spring.position):toBeTruthy()
			T.expect(math.abs(spring.position) < 1e6):toBeTruthy()
		end
	end)

	T.it("overshoots when under-damped and does not when critically damped", function()
		local under = Spring.new(0)
		under.target = 1
		local critical = Spring.new(0)
		critical.target = 1
		local maxUnder, maxCritical = 0, 0
		for _ = 1, 120 do
			Spring.step(under, 11, 0.5, 1 / 60)
			Spring.step(critical, 11, 1, 1 / 60)
			maxUnder = math.max(maxUnder, under.position)
			maxCritical = math.max(maxCritical, critical.position)
		end
		T.expect(maxUnder > 1):toBeTruthy()
		T.expect(maxCritical <= 1.001):toBeTruthy()
	end)

	T.it("ignores a non-positive timestep instead of corrupting itself", function()
		local spring = Spring.new(5)
		spring.target = 1
		Spring.step(spring, 10, 1, 0)
		T.expect(spring.position):toEqual(5)
	end)
end)

return true
