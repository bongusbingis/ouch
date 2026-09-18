-- Pure timed trajectories and their derivatives; no accumulated frame drift.
--!strict
local Profile = {}
local function ease(t: number): number
	return t * t * (3 - 2 * t)
end
local function rate(t: number): number
	return 6 * t * (1 - t)
end
function Profile.hammer(now: number, amplitude: number, windup: number, strike: number, phase: number): (number, number)
	local t = (now + phase) % (windup + strike)
	if t < windup then
		return amplitude * (2 * ease(t / windup) - 1), 2 * amplitude * rate(t / windup) / windup
	end
	t = (t - windup) / strike
	return amplitude * (1 - 2 * ease(t)), -2 * amplitude * rate(t) / strike
end
function Profile.piston(now: number, extent: number, period: number, hold: number, phase: number): (number, number)
	local t = (now + phase) % period
	local extend = (period - hold) * 0.2
	local retract = (period - hold) * 0.3
	if t < extend then
		return extent * ease(t / extend), extent * rate(t / extend) / extend
	end
	if t < extend + hold then
		return extent, 0
	end
	if t < extend + hold + retract then
		local a = (t - extend - hold) / retract
		return extent * (1 - ease(a)), -extent * rate(a) / retract
	end
	return 0, 0
end
function Profile.spin(
	now: number,
	speed: number,
	acceleration: number,
	epoch: number,
	phaseDegrees: number
): (number, number)
	local t = if acceleration == 0 then now else math.max(now - epoch, 0)
	return math.rad((speed * t + 0.5 * acceleration * t * t + phaseDegrees) % 360), math.rad(speed + acceleration * t)
end
return Profile
