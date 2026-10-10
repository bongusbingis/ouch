-- Name: RaceTrail.luau
-- Author: Jack C.
-- Description: Pure gate between a racer's fully validated movement samples and checkpoint credit: samples queue behind the last credited anchor and are released as one path only once the path's horizontal length fits the sustained speed the Guard allowed since the anchor plus a banked slack, so a burst-tolerated hop into a trigger earns nothing before the racer could have run there, and an honest racer's crossing is credited late but never dropped.
-- Created: 2026-10-09

--!strict

local RaceTrail = {}

export type Trail = {
	-- Last credited sample: every released path starts here.
	at: number,
	position: vector,
	-- Validated samples since the anchor, in order, with their horizontal length.
	path: { vector },
	times: { number },
	length: number,
	-- Unspent allowance carried over from the last release, never more than slack, so chained small hops
	-- cannot re-earn the slack on every sample.
	bank: number,
	slack: number,
	-- Highest per-second horizontal allowance seen since the anchor (fans, shoves, carries raise it).
	limit: number,
}

function RaceTrail.new(at: number, position: vector, slack: number): Trail
	return { at = at, position = position, path = {}, times = {}, length = 0, bank = slack, slack = slack, limit = 0 }
end

local function allowed(trail: Trail, at: number): number
	return trail.bank + math.max(at - trail.at, 0) * trail.limit
end

-- Hands back anchor + pending samples as one path and makes the last sample the new anchor.
local function release(trail: Trail, budget: number, limit: number): ({ vector }, { number })
	local points = { trail.position }
	local times = { trail.at }
	table.move(trail.path, 1, #trail.path, 2, points)
	table.move(trail.times, 1, #trail.times, 2, times)
	trail.position = points[#points]
	trail.at = times[#times]
	trail.bank = math.clamp(budget - trail.length, 0, trail.slack)
	trail.path = {}
	trail.times = {}
	trail.length = 0
	trail.limit = limit
	return points, times
end

-- Offers the next validated sample. Returns the path to credit (points and their times, anchor first)
-- once its length fits the budget, else nil and keeps queueing: a later sample re-tries the whole path.
function RaceTrail.advance(trail: Trail, at: number, position: vector, limit: number): ({ vector }?, { number }?)
	trail.limit = math.max(trail.limit, limit)
	local last = trail.path[#trail.path] or trail.position
	local delta = position - last
	trail.length += vector.magnitude(vector.create(delta.x, 0, delta.z))
	table.insert(trail.path, position)
	table.insert(trail.times, at)
	local budget = allowed(trail, at)
	if trail.length > budget then
		return nil, nil
	end
	return release(trail, budget, limit)
end

-- Releases whatever is queued without waiting for another sample. With fit, only when the queued
-- length fits the budget as of `at` (a later time than the last sample can only add sustained-speed
-- allowance); without fit, unconditionally (the round is closing and nothing can be re-tried).
function RaceTrail.flush(trail: Trail, at: number, fit: boolean): ({ vector }?, { number }?)
	if #trail.path == 0 then
		return nil, nil
	end
	local budget = allowed(trail, at)
	if fit and trail.length > budget then
		return nil, nil
	end
	return release(trail, budget, trail.limit)
end

return RaceTrail
