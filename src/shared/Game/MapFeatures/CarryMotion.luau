-- Pure rigid-support delta, retaining world-up avatar orientation.
--!strict
local CarryMotion = {}
function CarryMotion.delta(previous: CFrame, current: CFrame, position: Vector3, limit: number): Vector3?
	local delta = current:PointToWorldSpace(previous:PointToObjectSpace(position)) - position
	if delta.Magnitude > limit then
		return nil
	end
	return delta
end
return table.freeze(CarryMotion)
