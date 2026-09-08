-- Description: Pure rotation schedule for authored spinning geometry, deriving the angle from the synchronized clock alone so machines never drift apart.

--!strict

local Rotation = {}

function Rotation.angleAt(now: number, degreesPerSecond: number): number
	return math.rad((now * degreesPerSecond) % 360)
end

return table.freeze(Rotation)
