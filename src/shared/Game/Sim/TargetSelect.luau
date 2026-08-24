--!strict

local SimTypes = require(script.Parent.SimTypes)
local SimUtil = require(script.Parent.SimUtil)

type Vec = SimTypes.Vec
type WorldSnapshot = SimTypes.WorldSnapshot

-- Shared scored target selection for weapon assists.
--
-- Scoring is angle first, distance as a small tiebreak, so the enemy nearest the
-- centre of aim wins and two at the same angle resolve by proximity. Iteration
-- is over sorted keys, so the result is identical for identical inputs.
--
-- Confidence is normalized within the target cone so assists fade at its edge.

local TargetSelect = {}

export type Options = {
	-- Furthest a candidate may be, in studs.
	rangeStuds: number,
	-- Half-angle around the aim direction that admits a candidate, in degrees.
	coneDeg: number,
	-- Fraction of the cone that still scores full confidence.
	fadeStartFraction: number,
	-- Sphere radius for the line-of-sight check, or nil to skip the check --
	-- melee at contact range does not need one and would fail it against the
	-- target's own capsule.
	lineOfSightRadius: number?,
}

local function confidenceFor(angleRadians: number, coneRadians: number, fadeStartFraction: number): number
	if coneRadians <= 1e-6 then
		return 0
	end
	local fraction = math.clamp(angleRadians / coneRadians, 0, 1)
	local fadeStart = math.clamp(fadeStartFraction, 0, 1)
	if fraction <= fadeStart or fadeStart >= 1 then
		return 1
	end
	return 1 - (fraction - fadeStart) / (1 - fadeStart)
end

-- Best enemy in the cone, plus how confident the pick is. Returns nil and zero
-- when nothing qualifies; callers treat that as "no assist" rather than as an
-- error, because pointing at empty space is a normal thing to do.
function TargetSelect.pick(
	world: WorldSnapshot,
	selfId: string,
	origin: Vec,
	direction: Vec,
	options: Options
): (string?, number)
	local coneRadians = math.rad(options.coneDeg)
	local cosCone = math.cos(coneRadians)
	local best: string? = nil
	local bestScore = math.huge
	local bestAngle = 0

	for _, characterId in SimUtil.sortedKeys(world.characters) do
		if characterId == selfId or SimUtil.sameTeam(world, selfId, characterId) then
			continue
		end
		local character = world.characters[characterId]
		if not character.alive or character.invulnerable then
			continue
		end
		local toTarget = character.position - origin
		local distance = vector.magnitude(toTarget)
		if distance <= 1e-6 or distance > options.rangeStuds then
			continue
		end
		local dot = vector.dot(direction, toTarget / distance)
		if dot < cosCone then
			continue
		end
		local radius = options.lineOfSightRadius
		if radius ~= nil and not SimUtil.hasLineOfSight(world, origin, character, radius) then
			continue
		end

		local angle = math.acos(math.clamp(dot, -1, 1))
		local score = angle + distance * 1e-3
		if score < bestScore then
			best = characterId
			bestScore = score
			bestAngle = angle
		end
	end

	if best == nil then
		return nil, 0
	end
	return best, confidenceFor(bestAngle, coneRadians, options.fadeStartFraction)
end

-- Rotates a direction toward a point by at most maxAngleRadians, scaled by
-- strength. Used wherever an assist nudges aim rather than replacing it: the
-- clamp is what keeps the result recognisable as the player's own input.
function TargetSelect.steer(direction: Vec, origin: Vec, point: Vec, strength: number, maxAngleRadians: number): Vec
	local toPoint = point - origin
	local distance = vector.magnitude(toPoint)
	if distance <= 1e-4 or strength <= 0 then
		return direction
	end
	local desired = toPoint / distance
	local angle = math.acos(math.clamp(vector.dot(direction, desired), -1, 1))
	if angle <= 1e-5 then
		return direction
	end

	local allowed = math.min(angle * math.clamp(strength, 0, 1), maxAngleRadians)
	if allowed <= 1e-5 then
		return direction
	end
	local blended = direction + (desired - direction) * (allowed / angle)
	local length = vector.magnitude(blended)
	if length <= 1e-4 then
		return direction
	end
	return blended / length
end

return table.freeze(TargetSelect)
