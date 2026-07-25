--!strict

-- Dimension-based fallback grip for symmetric double-headed hammer meshes.

local HammerGrip = {}

export type Axis = "X" | "Y" | "Z"
export type Solution = {
	axis: Axis,
	position: { x: number, y: number, z: number },
	rotationDeg: { x: number, y: number, z: number },
}

function HammerGrip.longestAxis(sizeX: number, sizeY: number, sizeZ: number): (Axis, number, number)
	local axis: Axis = "X"
	local longest = sizeX
	if sizeY > longest then
		axis = "Y"
		longest = sizeY
	end
	if sizeZ > longest then
		axis = "Z"
		longest = sizeZ
	end

	local second = if axis == "X"
		then math.max(sizeY, sizeZ)
		elseif axis == "Y" then math.max(sizeX, sizeZ)
		else math.max(sizeX, sizeY)
	return axis, longest, second
end

function HammerGrip.solve(
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	minAxisDominanceRatio: number,
	gripAlongLongAxis: number
): Solution?
	assert(minAxisDominanceRatio > 1, "[HammerGrip] minAxisDominanceRatio must be greater than 1")
	local axis, longest, second = HammerGrip.longestAxis(sizeX, sizeY, sizeZ)
	if longest <= 0 or second <= 0 or longest / second < minAxisDominanceRatio then
		return nil
	end

	local distance = longest * gripAlongLongAxis
	local position = { x = 0, y = 0, z = 0 }
	local rotationDeg = { x = 0, y = 0, z = 0 }
	if axis == "X" then
		position.x = distance
		rotationDeg.z = -90
	elseif axis == "Y" then
		position.y = distance
	else
		position.z = distance
		rotationDeg.x = 90
	end
	return {
		axis = axis,
		position = position,
		rotationDeg = rotationDeg,
	}
end

return HammerGrip
