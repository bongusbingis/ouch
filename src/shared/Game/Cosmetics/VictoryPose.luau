-- Pure looping pose samples for cosmetic display rigs, independent of gameplay animations.
--!strict

local VictoryPose = {}
local tau = math.pi * 2

function VictoryPose.sample(pose: string, time: number, duration: number, reducedMotion: boolean?): any
	local phase = if reducedMotion then 0.2 else (math.max(time, 0) % duration) / duration
	local beat = math.sin(phase * tau * 2)
	local result = {
		lift = 0,
		yaw = 0,
		lean = 0,
		leftArm = 0,
		rightArm = 0,
		leftElbow = 0,
		rightElbow = 0,
		leftLeg = 0,
		rightLeg = 0,
	}
	if pose == "Twirl" then
		result.yaw = if reducedMotion then 0 else phase * tau
		result.lift = if reducedMotion then 0 else 0.12 * (1 - math.cos(phase * tau))
		result.leftArm = -1.8
		result.rightArm = 1.8
		result.leftElbow = -0.4
		result.rightElbow = 0.4
	elseif pose == "Flex" then
		result.leftArm = -1.25
		result.rightArm = 1.25
		result.leftElbow = -1.5
		result.rightElbow = 1.5
		result.lean = if reducedMotion then 0 else beat * 0.08
		result.lift = if reducedMotion then 0 else math.max(beat, 0) * 0.08
	elseif pose == "Bounce" then
		result.lift = if reducedMotion then 0 else math.max(beat, 0) * 0.45
		result.lean = if reducedMotion then 0 else beat * 0.12
		result.leftArm = -1.6 - beat * 0.35
		result.rightArm = 1.6 - beat * 0.35
		result.leftLeg = if reducedMotion then 0 else math.min(beat, 0) * 0.25
		result.rightLeg = -result.leftLeg
	else
		result.rightArm = 2.15 + beat * 0.2
		result.rightElbow = 0.45 + beat * 0.25
		result.leftArm = -0.15
		result.lean = 0.04
	end
	return result
end

return table.freeze(VictoryPose)
