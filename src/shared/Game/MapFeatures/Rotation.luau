--!strict

-- Pure rotation schedule for authored spinning geometry. The angle is a
-- function of the synchronized clock alone, never of accumulated frame deltas,
-- so the server and every predicting client compute the same pose for the same
-- instant instead of drifting apart at different frame rates.

local Rotation = {}

function Rotation.angleAt(now: number, degreesPerSecond: number): number
	return math.rad((now * degreesPerSecond) % 360)
end

return table.freeze(Rotation)
