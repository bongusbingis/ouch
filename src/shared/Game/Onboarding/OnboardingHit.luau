-- Name: OnboardingHit.luau
-- Author: Jack C.
-- Description: Pure hit predicates for first-session training targets. Mirrors the geometry the real weapons use -- the hammer's forward/lateral/height cone and a swept segment for a thrown ball -- so a training dummy is judged by the same shape as a live opponent without having to be a simulation entity.
-- Created: 2026-08-26

--!strict

local OnboardingHit = {}

export type Vec = vector

export type HammerCone = {
	Range: number,
	Width: number,
	Height: number,
}

-- Mirrors the target test in Sim/Weapons/Hammer.luau: forward reach, flat
-- lateral spread, then a vertical band. Deliberately a separate pure copy rather
-- than a call into the kit, because a training dummy is not a simulation
-- character and never appears in a WorldSnapshot for the kit to scan.
function OnboardingHit.withinHammerCone(
	origin: Vec,
	direction: Vec,
	targetPosition: Vec,
	targetRadius: number,
	cone: HammerCone
): boolean
	local length = vector.magnitude(direction)
	if length <= 1e-6 then
		return false
	end
	local unit = direction / length
	local offset = targetPosition - origin
	local forward = vector.dot(offset, unit)
	if forward < 0 or forward > cone.Range + targetRadius then
		return false
	end
	local flatOffset = vector.create(offset.x, 0, offset.z)
	local lateral = vector.magnitude(flatOffset - unit * forward)
	if lateral > cone.Width * 0.5 + targetRadius then
		return false
	end
	return math.abs(offset.y) <= cone.Height * 0.5
end

-- Balls are CFrame-driven between ticks rather than physics bodies, so contact
-- is a distance test against the segment the ball covered this frame. A point
-- test would let a fast throw pass clean through a dummy between two samples.
function OnboardingHit.ballReachedTarget(
	previousPosition: Vec,
	currentPosition: Vec,
	targetPosition: Vec,
	radius: number
): boolean
	local segment = currentPosition - previousPosition
	local lengthSquared = vector.dot(segment, segment)
	local closest: Vec
	if lengthSquared <= 1e-6 then
		closest = currentPosition
	else
		local alpha = math.clamp(vector.dot(targetPosition - previousPosition, segment) / lengthSquared, 0, 1)
		closest = previousPosition + segment * alpha
	end
	return vector.magnitude(closest - targetPosition) <= radius
end

return table.freeze(OnboardingHit)
