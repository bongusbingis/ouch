--!strict

-- Pure maths for the throwing-arm pose: how strongly the solver pulls, and how
-- far into the wind-up the hand has travelled.
--
-- Touches no instance and knows nothing about rigs, so it runs headlessly and is
-- the part of the pose system that can actually be tested. Everything is plain
-- numbers; the client module owns the Vector3 and CFrame work.
--
-- Nothing here poses a torso, a head or a facing direction. The body belongs to
-- the authored animation.

local AimPose = {}

-- How hard the solver pulls, from the weight its state asks for and how far the
-- throw is charged. Charge raises it, because a wound-up arm should read more
-- strongly the longer it is held, but the result is always a blend -- never 1,
-- which would hand the arm entirely to the solver and delete the authored
-- motion underneath it.
function AimPose.weight(stateWeight: number, chargeAlpha: number, chargeBoost: number, maxWeight: number): number
	local charged = stateWeight + math.clamp(chargeAlpha, 0, 1) * chargeBoost
	return math.clamp(charged, 0, math.clamp(maxWeight, 0, 1))
end

-- How far the wind-up reaches at a given charge, as a multiplier on the
-- configured offset. 1 at no charge so entering the wind-up is immediate and
-- committed rather than creeping outward from nothing; the stretch is what makes
-- a full charge visibly bigger than a light one.
function AimPose.windupReach(chargeAlpha: number, chargeStretch: number): number
	return 1 + math.max(chargeStretch, 0) * math.clamp(chargeAlpha, 0, 1)
end

return table.freeze(AimPose)
