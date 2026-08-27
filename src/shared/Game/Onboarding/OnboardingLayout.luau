-- Name: OnboardingLayout.luau
-- Author: Jack C.
-- Description: Pure geometry for the tutorial arena. Derives one frame of reference from the authored MapOrigin and PlayerSpawn markers, then answers every positional question the training flow asks -- where a dummy stands, where a waypoint sits, whether the player is on the bridge or out over the elimination ring -- so no module measures the map for itself.
-- Created: 2026-08-26

--!strict

local OnboardingLayout = {}

export type Vec = vector

-- One frame of reference for the whole arena: the centre, the axis the player
-- travels along, and the height they walk at. Everything else is expressed as a
-- distance out from the centre and an offset to one side, so the arena can be
-- moved or re-authored without a single position needing to be rewritten.
export type Frame = {
	origin: Vec,
	forward: Vec,
	right: Vec,
	surfaceY: number,
}

local UP = vector.create(0, 1, 0)

local function flatten(value: Vec): Vec
	return vector.create(value.x, 0, value.z)
end

function OnboardingLayout.frame(origin: Vec, spawn: Vec, surfaceOffsetY: number): Frame
	local toSpawn = flatten(spawn - origin)
	-- A spawn directly above the centre leaves no axis to derive; falling back to
	-- world +X keeps the frame well-formed rather than producing NaN positions.
	local forward = if vector.magnitude(toSpawn) > 1e-3 then vector.normalize(toSpawn) else vector.create(1, 0, 0)
	return {
		origin = vector.create(origin.x, origin.y + surfaceOffsetY, origin.z),
		forward = forward,
		right = vector.cross(UP, forward),
		surfaceY = origin.y + surfaceOffsetY,
	}
end

-- Distance is measured out from the centre along the player's approach axis;
-- lateral steps to the side of it. Both are in studs.
function OnboardingLayout.point(frame: Frame, distance: number, lateral: number): Vec
	local flat = frame.origin + frame.forward * distance + frame.right * lateral
	return vector.create(flat.x, frame.surfaceY, flat.z)
end

function OnboardingLayout.ringPoint(frame: Frame, radius: number, index: number, count: number): Vec
	local angle = ((index - 1) / math.max(count, 1)) * math.pi * 2
	return OnboardingLayout.point(frame, math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Unsigned horizontal distance from the arena centre.
function OnboardingLayout.distanceFromCentre(frame: Frame, position: Vec): number
	return vector.magnitude(flatten(position - frame.origin))
end

-- Unsigned distance from the approach axis. Both bridges lie on that axis, so
-- this is what separates "crossing on a bridge" from "out over the ring".
function OnboardingLayout.lateralOffset(frame: Frame, position: Vec): number
	local flat = flatten(position - frame.origin)
	return math.abs(vector.dot(flat, frame.right))
end

function OnboardingLayout.onBridge(
	frame: Frame,
	position: Vec,
	innerRadius: number,
	outerRadius: number,
	halfWidth: number
): boolean
	local distance = OnboardingLayout.distanceFromCentre(frame, position)
	if distance < innerRadius or distance > outerRadius then
		return false
	end
	return OnboardingLayout.lateralOffset(frame, position) <= halfWidth
end

-- The elimination ring is everything in the radial band that is not on a bridge.
-- Expressed as a band rather than a part so it cannot break when the map's own
-- geometry is renamed or re-exported.
function OnboardingLayout.overEliminationRing(
	frame: Frame,
	position: Vec,
	innerRadius: number,
	outerRadius: number,
	bridgeHalfWidth: number
): boolean
	local distance = OnboardingLayout.distanceFromCentre(frame, position)
	if distance <= innerRadius or distance >= outerRadius then
		return false
	end
	return OnboardingLayout.lateralOffset(frame, position) > bridgeHalfWidth
end

return table.freeze(OnboardingLayout)
