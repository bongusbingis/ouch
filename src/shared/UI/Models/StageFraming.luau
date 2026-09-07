-- Fits a world-space showcase into an unobstructed rectangle of the full-screen camera.
--!strict

local StageFraming = {}

function StageFraming.camera(
	target: Vector3,
	span: Vector2,
	position: Vector2,
	size: Vector2,
	viewport: Vector2,
	fov: number
): CFrame
	local width, height = math.max(viewport.X, 1), math.max(viewport.Y, 1)
	local regionWidth, regionHeight = math.max(size.X, 1), math.max(size.Y, 1)
	local tangent = math.tan(math.rad(fov / 2))
	local distance = math.max(span.Y * height / regionHeight, span.X * height / regionWidth) / (2 * tangent)
	local frame = CFrame.lookAt(target + Vector3.new(0, distance * 0.16, distance), target)
	local halfHeight = (frame.Position - target).Magnitude * tangent
	local centerX, centerY = position.X + size.X / 2, position.Y + size.Y / 2
	local x, y = centerX / width * 2 - 1, centerY / height * 2 - 1
	return frame * CFrame.new(-x * halfHeight * width / height, y * halfHeight, 0)
end

return table.freeze(StageFraming)
