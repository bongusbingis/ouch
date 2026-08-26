-- Name: Intercept.luau
-- Author: Jack C.
-- Description: Pure interception maths: where to aim to lead a moving target, how consistent that target's recent motion has been, and how far to bias aim by that confidence.
-- Created: 2026-08-19

--!strict

local SimTypes = require(script.Parent.SimTypes)

type Vec = SimTypes.Vec

local Intercept = {}

local MAX_ITERATIONS = 3

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

	local alpha = allowed / angle
	local blended = aimDir + (desired - aimDir) * alpha
	local blendedLength = vector.magnitude(blended)
	if blendedLength <= 1e-4 then
		return aimDir
	end
	return blended / blendedLength
end

return table.freeze(Intercept)
