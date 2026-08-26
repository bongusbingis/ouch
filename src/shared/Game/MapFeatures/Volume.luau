-- Name: Volume.luau
-- Author: Jack C.
-- Description: Volume test shared by every authored map feature, deciding when a character's root counts as inside a feature part with extra vertical padding.
-- Created: 2026-08-18

--!strict

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
