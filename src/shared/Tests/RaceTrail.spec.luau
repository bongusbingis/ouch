-- Name: RaceTrail.spec.luau
-- Author: Jack C.
-- Description: Spec for the Splashdown credit gate: a steady sprint is credited every sample, a burst hop the Guard accepts is credited no sooner than a run there, a held path is released whole so a crossing on a turn or drop is never lost, chained small hops cannot re-earn the slack, a carry at zero headroom resolves after dismount, a server allowance widens the budget, and a closing round releases a pending path unconditionally.
-- Created: 2026-10-09

--!strict

local T = require(script.Parent.TestKit)
local RaceTrail = require(script.Parent.Parent.Game.Splashdown.RaceTrail)

local LIMIT = 16 * 1.6 + 8 -- the Guard's walk limit at WalkSpeed 16
local SLACK = 6
local STEP = 0.1

local function at(x: number, z: number?, y: number?): vector
	return vector.create(x, y or 0, z or 0)
end

-- Offers samples until one is released; returns the release time and the path, or nil.
local function offer(trail: RaceTrail.Trail, from: number, to: number, position: (number) -> vector, limit: number)
	for index = 1, math.round((to - from) / STEP) do
		local now = from + index * STEP
		local points, times = RaceTrail.advance(trail, now, position(now), limit)
		if points then
			return now, points, times
		end
	end
	return nil, nil, nil
end

T.describe("RaceTrail", function()
	T.it("credits a steady sprint on every sample from the previous one", function()
		local trail = RaceTrail.new(0, at(0), SLACK)
		for index = 1, 20 do
			local points, times = RaceTrail.advance(trail, index * STEP, at(index * 3), LIMIT)
			T.expect(points and #points):toEqual(2)
			T.expect((points :: { vector })[1].x):toBeNear((index - 1) * 3)
			T.expect((times :: { number })[1]):toBeNear((index - 1) * STEP)
		end
	end)

	T.it("credits a 25-stud hop the Guard accepts no sooner than a sustained run there", function()
		-- A one-frame hop-and-return: the Guard accepts the hop, rejects the return and recovers the root
		-- onto the hop spot, so every accepted sample after the hop is at the trigger.
		local trail = RaceTrail.new(1, at(0), SLACK)
		local creditedAt, points = offer(trail, 1, 3, function()
			return at(25)
		end, LIMIT)
		T.expect(creditedAt ~= nil):toEqual(true)
		T.expect((creditedAt :: number) - 1 >= (25 - SLACK) / LIMIT - 1e-6):toEqual(true)
		T.expect((points :: { vector })[1]):toEqual(at(0))
		-- If the Guard later accepts a walk back, the out-and-back is charged in full.
		local back = RaceTrail.new(1, at(0), SLACK)
		T.expect(RaceTrail.advance(back, 1.1, at(25), LIMIT)):toBeNil()
		local backAt = offer(back, 1.1, 4, function(now)
			return if now < 1.45 then at(25) else at(0)
		end, LIMIT)
		T.expect((backAt :: number) - 1 >= (50 - SLACK) / LIMIT - 1e-6):toEqual(true)
	end)

	T.it("releases a held path whole, so a crossing before a turn and drop is kept", function()
		local trail = RaceTrail.new(0, at(0), SLACK)
		-- A replication hitch: 16 studs arrive in one sample (over 6 + 3.36), then the racer turns and drops.
		T.expect(RaceTrail.advance(trail, 0.1, at(16), LIMIT)):toBeNil()
		local creditedAt, points, times = offer(trail, 0.1, 2, function(now)
			return at(16, (now - 0.1) * 16, -(now - 0.1) * 30)
		end, LIMIT)
		T.expect(creditedAt ~= nil):toEqual(true)
		T.expect((points :: { vector })[1]):toEqual(at(0))
		T.expect((points :: { vector })[2]):toEqual(at(16))
		T.expect((times :: { number })[2]):toBeNear(0.1)
		-- Delay bound: excess / (limit - speed) = (16 - 9.36) / (33.6 - 16) ~ 0.38 s.
		T.expect((creditedAt :: number) <= 0.1 + 0.5):toEqual(true)
	end)

	T.it("does not re-grant the slack to chained small hops", function()
		local trail = RaceTrail.new(0, at(0), SLACK)
		local credited = 0
		for index = 1, 20 do
			local points = RaceTrail.advance(trail, index * STEP, at(index * 8.5), LIMIT)
			if points then
				credited = points[#points].x
			end
		end
		T.expect(credited <= SLACK + 2 * LIMIT + 1e-6):toEqual(true)
		T.expect(credited < 20 * 8.5):toEqual(true)
	end)

	T.it("holds at zero headroom on a carrier and resolves after dismount", function()
		local carry = 36 -- ServerRiders allowance WalkSpeed + carrier speed: the racer moves at exactly the limit
		local trail = RaceTrail.new(0, at(0), SLACK)
		T.expect(RaceTrail.advance(trail, 0.1, at(10), carry)):toBeNil()
		local carriedAt = offer(trail, 0.1, 1.1, function(now)
			return at(10 + (now - 0.1) * carry)
		end, carry)
		T.expect(carriedAt):toBeNil()
		local creditedAt, points = offer(trail, 1.1, 2, function(now)
			return at(10 + 36 + (now - 1.1) * 16)
		end, LIMIT)
		T.expect(creditedAt ~= nil):toEqual(true)
		T.expect((points :: { vector })[1]):toEqual(at(0))
		T.expect(#(points :: { vector }) >= 12):toEqual(true)
	end)

	T.it("widens the budget for a live allowance and keeps it while held", function()
		local held = RaceTrail.new(0, at(0), SLACK)
		T.expect(RaceTrail.advance(held, 0.1, at(30), 97)):toBeNil()
		-- The fan allowance expired by the next check, but the move happened under it.
		T.expect(RaceTrail.advance(held, 0.25, at(30), LIMIT)):toBeTruthy()
	end)

	T.it("releases a pending path at round close without the fit check", function()
		local trail = RaceTrail.new(0, at(0), SLACK)
		T.expect(RaceTrail.flush(trail, 0.1, false)):toBeNil()
		T.expect(RaceTrail.advance(trail, 0.1, at(20), LIMIT)):toBeNil()
		T.expect(RaceTrail.flush(trail, 0.1, true)):toBeNil()
		local points, times = RaceTrail.flush(trail, 0.1, false)
		T.expect(points and points[2]):toEqual(at(20))
		T.expect(times and times[2]):toBeNear(0.1)
		T.expect(#trail.path):toEqual(0)
		T.expect(trail.position):toEqual(at(20))
	end)
end)

return true
