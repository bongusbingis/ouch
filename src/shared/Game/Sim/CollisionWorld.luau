-- Name: CollisionWorld.luau
-- Author: Jack C.
-- Description: Pure collision maths for the simulation: closest points on segments, swept sphere against capsule tests, and the clamped rotation helper used for homing.
-- Created: 2026-07-12

--!strict

local SimTypes = require(script.Parent.SimTypes)

type Vec = SimTypes.Vec
type CharacterSnapshot = SimTypes.CharacterSnapshot

local CollisionWorld = {}

local EPSILON = 1e-9

function CollisionWorld.closestPointOnSegment(point: Vec, a: Vec, b: Vec): Vec
	local ab = b - a
	local lengthSq = vector.dot(ab, ab)
	if lengthSq <= EPSILON then
		return a
	end
	local t = math.clamp(vector.dot(point - a, ab) / lengthSq, 0, 1)
	return a + ab * t
end

function CollisionWorld.segmentSegmentClosest(p1: Vec, q1: Vec, p2: Vec, q2: Vec): (number, number)
	local d1 = q1 - p1
	local d2 = q2 - p2
	local r = p1 - p2
	local a = vector.dot(d1, d1)
	local e = vector.dot(d2, d2)
	local f = vector.dot(d2, r)

	if a <= EPSILON and e <= EPSILON then
		return 0, 0
	end
	if a <= EPSILON then
		return 0, math.clamp(f / e, 0, 1)
	end

	local c = vector.dot(d1, r)
	if e <= EPSILON then
		return math.clamp(-c / a, 0, 1), 0
	end

	local b = vector.dot(d1, d2)
	local denom = a * e - b * b
	local s = if denom > EPSILON then math.clamp((b * f - c * e) / denom, 0, 1) else 0
	local t = (b * s + f) / e

	if t < 0 then
		t = 0
		s = math.clamp(-c / a, 0, 1)
	elseif t > 1 then
		t = 1
		s = math.clamp((b - c) / a, 0, 1)
	end
	return s, t
end

export type CapsuleSweepHit = {
	fraction: number,
	position: Vec,
}

function CollisionWorld.sweptSphereVsCapsule(
	from: Vec,
	to: Vec,
	sumRadius: number,
	capA: Vec,
	capB: Vec
): CapsuleSweepHit?
	local s, t = CollisionWorld.segmentSegmentClosest(from, to, capA, capB)
	local pathPoint = from + (to - from) * s
	local capPoint = capA + (capB - capA) * t
	if vector.magnitude(pathPoint - capPoint) > sumRadius then
		return nil
	end

	local function distanceAt(fraction: number): number
		local p = from + (to - from) * fraction
		return vector.magnitude(p - CollisionWorld.closestPointOnSegment(p, capA, capB))
	end

	if distanceAt(0) <= sumRadius then
		return { fraction = 0, position = from }
	end

	local lo, hi = 0, s
	for _ = 1, 8 do
		local mid = (lo + hi) / 2
		if distanceAt(mid) <= sumRadius then
			hi = mid
		else
			lo = mid
		end
	end
	return { fraction = hi, position = from + (to - from) * hi }
end

function CollisionWorld.rotateToward(dir: Vec, desired: Vec, maxAngle: number): Vec
	if maxAngle <= 0 then
		return dir
	end
	local cosAngle = math.clamp(vector.dot(dir, desired), -1, 1)
	if math.acos(cosAngle) <= maxAngle then
		return desired
	end

	local axis = vector.cross(dir, desired)
	if vector.magnitude(axis) < 1e-6 then
		axis = vector.cross(dir, vector.create(0, 1, 0))
		if vector.magnitude(axis) < 1e-6 then
			axis = vector.create(1, 0, 0)
		end
	end
	axis = vector.normalize(axis)

	local cosA = math.cos(maxAngle)
	local sinA = math.sin(maxAngle)
	return dir * cosA + vector.cross(axis, dir) * sinA + axis * (vector.dot(axis, dir) * (1 - cosA))
end

function CollisionWorld.capsuleEndpoints(character: CharacterSnapshot): (Vec, Vec)
	local halfAxis = math.max(character.height / 2 - character.radius, 0)
	local offset = vector.create(0, halfAxis, 0)
	return character.position - offset, character.position + offset
end

return CollisionWorld
