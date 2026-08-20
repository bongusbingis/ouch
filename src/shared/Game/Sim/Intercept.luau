--!strict

local SimTypes = require(script.Parent.SimTypes)

type Vec = SimTypes.Vec

-- Lead prediction: where to throw so the ball and a moving target arrive
-- together, and how much to trust that answer.
--
-- The dodgeball arcs, so there is no clean closed-form intercept. This solves it
-- by fixed-point iteration: guess a time of flight from the current distance,
-- move the target along its velocity by that long, recompute the distance, and
-- repeat. It converges in two or three passes for the speeds and ranges this
-- game uses, and the iteration count is capped -- trading exactness for a
-- bounded per-frame cost is the right side of that trade here, since being a
-- few centimetres off matters far less than a frame spike.
--
-- Confidence comes from how consistently the target has been moving. Leading a
-- player who is strafing erratically produces throws that look wrong to the
-- thrower and miss anyway, so the lead shrinks as direction variance rises.

local Intercept = {}

local MAX_ITERATIONS = 3

-- Predicted meeting point, or the target's current position when no useful
-- answer exists (stationary target, or a projectile too slow to ever arrive).
function Intercept.solve(origin: Vec, targetPosition: Vec, targetVelocity: Vec, projectileSpeed: number): Vec
	if projectileSpeed <= 1e-4 then
		return targetPosition
	end

	local predicted = targetPosition
	for _ = 1, MAX_ITERATIONS do
		local timeOfFlight = vector.magnitude(predicted - origin) / projectileSpeed
		predicted = targetPosition + targetVelocity * timeOfFlight
	end
	return predicted
end

-- 0-1 measure of how steadily a target has been moving, from a short rolling
-- window of velocity samples. 1 means a straight consistent line, 0 means the
-- direction is changing every sample. Fewer than two samples is treated as
-- unknown rather than confident.
function Intercept.consistency(samples: { Vec }): number
	if #samples < 2 then
		return 0
	end

	local agreement = 0
	local pairs = 0
	for index = 2, #samples do
		local previous = samples[index - 1]
		local current = samples[index]
		local previousSpeed = vector.magnitude(previous)
		local currentSpeed = vector.magnitude(current)
		-- A target that is barely moving is trivially consistent; treating it as
		-- unknown would suppress lead exactly when it is most reliable.
		if previousSpeed <= 1e-3 or currentSpeed <= 1e-3 then
			agreement += 1
		else
			local dot = vector.dot(previous / previousSpeed, current / currentSpeed)
			agreement += math.clamp((dot + 1) * 0.5, 0, 1)
		end
		pairs += 1
	end
	return if pairs > 0 then agreement / pairs else 0
end

-- Rotates aim from its current direction toward the intercept point, by at most
-- maxAngleRadians. The clamp is what keeps the assist from producing a throw
-- that visibly contradicts where the player pointed.
function Intercept.biasAim(
	aimDir: Vec,
	origin: Vec,
	interceptPoint: Vec,
	strength: number,
	maxAngleRadians: number
): Vec
	local toIntercept = interceptPoint - origin
	local distance = vector.magnitude(toIntercept)
	if distance <= 1e-4 or strength <= 0 then
		return aimDir
	end
	local desired = toIntercept / distance
	local dot = math.clamp(vector.dot(aimDir, desired), -1, 1)
	local angle = math.acos(dot)
	if angle <= 1e-5 then
		return aimDir
	end

	local allowed = math.min(angle * math.clamp(strength, 0, 1), maxAngleRadians)
	if allowed <= 1e-5 then
		return aimDir
	end

	-- Spherical interpolation by the allowed fraction of the full correction.
	local alpha = allowed / angle
	local blended = aimDir + (desired - aimDir) * alpha
	local blendedLength = vector.magnitude(blended)
	if blendedLength <= 1e-4 then
		return aimDir
	end
	return blended / blendedLength
end

return table.freeze(Intercept)
