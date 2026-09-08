-- Description: Pure steering for training throws. Turns a ball's velocity toward a target by a capped amount per tick, only while the target is ahead of it and in range, so a first throw curves in instead of sailing past.

--!strict

local OnboardingAssist = {}

export type Vec = vector

-- Returns the steered velocity, or nil when the ball should be left alone:
-- stationary, out of range, or aimed too far away from the target to be a throw
-- the player meant. Speed is always preserved, only the heading turns.
function OnboardingAssist.steer(
	position: Vec,
	velocity: Vec,
	target: Vec,
	maxTurnRadians: number,
	acquireCosine: number,
	maxRange: number
): Vec?
	local toTarget = target - position
	local distance = vector.magnitude(toTarget)
	if distance <= 1e-3 or distance > maxRange then
		return nil
	end
	local speed = vector.magnitude(velocity)
	if speed <= 1e-3 or maxTurnRadians <= 0 then
		return nil
	end

	local heading = velocity / speed
	local desired = toTarget / distance
	local alignment = math.clamp(vector.dot(heading, desired), -1, 1)
	if alignment < acquireCosine then
		return nil
	end
	if alignment >= 1 - 1e-9 then
		return nil
	end

	-- Rotate within the plane the two headings share, so the turn is a true arc
	-- rather than a lerp that would shorten the vector and bleed off speed.
	local residual = desired - heading * alignment
	local residualLength = vector.magnitude(residual)
	if residualLength <= 1e-6 then
		return nil
	end
	local perpendicular = residual / residualLength
	local turn = math.min(maxTurnRadians, math.acos(alignment))
	return (heading * math.cos(turn) + perpendicular * math.sin(turn)) * speed
end

return table.freeze(OnboardingAssist)
