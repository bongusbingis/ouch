--!strict

-- Volume test shared by every authored map feature. A character counts as
-- inside a feature part when its root sits within that part's box, with extra
-- vertical padding so a root hovering just above a floor-level pad or pit still
-- registers.
--
-- The bounds comparison is split from the transform so it stays pure and
-- spec-tested; `contains` is only the engine call that puts the point into the
-- part's local space.

local Volume = {}

function Volume.containsOffset(offset: Vector3, size: Vector3, verticalPadding: number): boolean
	return math.abs(offset.X) <= size.X / 2
		and math.abs(offset.Y) <= size.Y / 2 + verticalPadding
		and math.abs(offset.Z) <= size.Z / 2
end

function Volume.contains(partCFrame: CFrame, partSize: Vector3, position: Vector3, verticalPadding: number): boolean
	return Volume.containsOffset(partCFrame:PointToObjectSpace(position), partSize, verticalPadding)
end

return table.freeze(Volume)
