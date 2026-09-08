-- Description: Pure maths for the throwing-arm pose, deciding how strongly the solver pulls and how far into the wind-up the hand has travelled, in plain numbers with no rig knowledge.

--!strict

local AimPose = {}

function AimPose.weight(stateWeight: number, chargeAlpha: number, chargeBoost: number, maxWeight: number): number
	local charged = stateWeight + math.clamp(chargeAlpha, 0, 1) * chargeBoost
	return math.clamp(charged, 0, math.clamp(maxWeight, 0, 1))
end

function AimPose.windupReach(chargeAlpha: number, chargeStretch: number): number
	return 1 + math.max(chargeStretch, 0) * math.clamp(chargeAlpha, 0, 1)
end

return table.freeze(AimPose)
