--!strict

local T = require(script.Parent.TestKit)
local Spring = require(script.Parent.Parent.Game.Util.Spring)

local DT = 1 / 60

local function settle(spring: Spring.Spring, frequencyHz: number, dampingRatio: number, seconds: number)
	for _ = 1, math.floor(seconds / DT) do
		Spring.step(spring, frequencyHz, dampingRatio, DT)
	end
end

T.describe("Spring", function()
	T.it("converges to the target from a displacement", function()
		local spring = Spring.new(0)
		spring.position = 1
		settle(spring, 5, 0.3, 5)
		T.expect(spring.position):toBeNear(0, 1e-3)
		T.expect(spring.velocity):toBeNear(0, 1e-2)
	end)

	T.it("underdamped springs overshoot the target", function()
		local spring = Spring.new(0)
		spring.position = 1
		local minPosition = spring.position
		for _ = 1, 120 do
			Spring.step(spring, 5, 0.3, DT)
			minPosition = math.min(minPosition, spring.position)
		end
		T.expect(minPosition < -0.01):toBeTruthy()
	end)

	T.it("critically damped springs from rest never overshoot", function()
		local spring = Spring.new(0)
		spring.position = 1
		for _ = 1, 300 do
			Spring.step(spring, 5, 1, DT)
			T.expect(spring.position >= -1e-6):toBeTruthy()
		end
	end)

	T.it("impulse adds exactly to velocity", function()
		local spring = Spring.new(0)
		Spring.impulse(spring, 4)
		T.expect(spring.velocity):toEqual(4)
		Spring.impulse(spring, -1.5)
		T.expect(spring.velocity):toEqual(2.5)
	end)

	T.it("identical step sequences are deterministic", function()
		local a = Spring.new(0)
		local b = Spring.new(0)
		Spring.impulse(a, -10)
		Spring.impulse(b, -10)
		for _ = 1, 90 do
			Spring.step(a, 5.5, 0.32, DT)
			Spring.step(b, 5.5, 0.32, DT)
			T.expect(a.position):toEqual(b.position)
			T.expect(a.velocity):toEqual(b.velocity)
		end
	end)

	T.it("clamps huge dt so a hitch frame stays bounded", function()
		local spring = Spring.new(0)
		spring.position = 1
		Spring.step(spring, 5, 0.3, 10)
		T.expect(math.abs(spring.position) < 10):toBeTruthy()
		T.expect(math.abs(spring.velocity) < 100):toBeTruthy()
	end)
end)

return true
