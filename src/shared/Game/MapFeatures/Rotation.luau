-- Description: Pure rotation schedule for authored spinning geometry, deriving the angle from the synchronized clock alone so machines never drift apart.

--!strict

local Rotation = {}

function Rotation.angleAt(now: number, degreesPerSecond: number): number
	return math.rad((now * degreesPerSecond) % 360)
end

function Rotation.rockAt(now: number, amplitude: number, period: number, phase: number): number
	return amplitude * math.sin((now + phase) / period * 2 * math.pi)
end

-- A slide is the same oscillation measured in studs along an axis.
function Rotation.slideAt(now: number, amplitude: number, period: number, phase: number): number
	return Rotation.rockAt(now, amplitude, period, phase)
end

-- Rate of change of rockAt / slideAt, so a shove can follow the surface.
function Rotation.rockRateAt(now: number, amplitude: number, period: number, phase: number): number
	local omega = 2 * math.pi / period
	return amplitude * omega * math.cos((now + phase) * omega)
end

return table.freeze(Rotation)
