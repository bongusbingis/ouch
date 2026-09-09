-- Description: Pure rotation schedule for authored spinning geometry, deriving the angle from the synchronized clock alone so machines never drift apart.

--!strict

local Rotation = {}

function Rotation.angleAt(now: number, degreesPerSecond: number): number
	return math.rad((now * degreesPerSecond) % 360)
end

function Rotation.rockAt(now: number, amplitude: number, period: number, phase: number): number
	return amplitude * math.sin((now + phase) / period * 2 * math.pi)
end

return table.freeze(Rotation)
