--!strict
-- Bounded per-piece target velocities, never additive impulses. Unmarked arena
-- pieces retain their defaults, and the movement allowance outlasts the hold.
local ShoveTuning = {}

local function bounded(value: any, fallback: number, minimum: number, maximum: number): number
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

function ShoveTuning.resolve(defaults, speed: any, upward: any, seconds: any)
	local hold = bounded(seconds, defaults.ShoveSeconds, 0.08, 0.4)
	return {
		KnockbackSpeed = bounded(speed, defaults.KnockbackSpeed, 8, 80),
		UpwardSpeed = bounded(upward, defaults.UpwardSpeed, 0, 36),
		ShoveSeconds = hold,
		GuardSeconds = math.max(defaults.GuardSeconds, hold + 0.3),
	}
end

return table.freeze(ShoveTuning)
