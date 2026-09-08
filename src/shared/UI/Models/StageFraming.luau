-- Fits a world-space showcase into an unobstructed rectangle of the full-screen camera.
--!strict

local StageFraming = {}

function StageFraming.boxPoints(frame: CFrame, minimum: Vector3, maximum: Vector3): { Vector3 }
	local points = {}
	for _, x in { minimum.X, maximum.X } do
		for _, y in { minimum.Y, maximum.Y } do
			for _, z in { minimum.Z, maximum.Z } do
				table.insert(points, frame * Vector3.new(x, y, z))
			end
		end
	end
	return points
end

function StageFraming.pointsCamera(
	reference: CFrame,
	points: { Vector3 },
	position: Vector2,
	size: Vector2,
	viewport: Vector2,
	fov: number,
	viewTarget: Vector3?
): CFrame
	if #points == 0 or viewport.X <= 1 or viewport.Y <= 1 or size.X <= 1 or size.Y <= 1 then
		return reference
	end
	local minimum, maximum = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, point in points do
		minimum = minimum:Min(point)
		maximum = maximum:Max(point)
	end
	local height = viewport.Y
	local tangent = math.tan(math.rad(fov / 2))
	local halfX = math.max(size.X, 1) / height * tangent
	local halfY = math.max(size.Y, 1) / height * tangent
	local centerX = (position.X * 2 + size.X - viewport.X) / height * tangent
	local centerY = (height - position.Y * 2 - size.Y) / height * tangent
	local center = (minimum + maximum) / 2
	local sightline = reference.Position - (viewTarget or center)
	local back = if sightline.Magnitude > 0.001 then sightline.Unit else reference.ZVector
	local right = reference.UpVector:Cross(back)
	right = if right.Magnitude > 0.001 then right.Unit else reference.RightVector
	local orientation = CFrame.fromMatrix(Vector3.zero, right, back:Cross(right), back)
	local ray = Vector3.new(centerX, centerY, -1).Unit
	local axis = ray:Cross(-Vector3.zAxis)
	local correction = if axis.Magnitude > 0.001
		then CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(-ray.Z, -1, 1)))
		else CFrame.identity
	local frame = orientation * correction + center
	local distance = 0
	for _, vertex in points do
		local point = frame:PointToObjectSpace(vertex)
		distance = math.max(
			distance,
			point.Z + 0.1,
			-(point.X + (centerX - halfX) * point.Z) / halfX,
			(point.X + (centerX + halfX) * point.Z) / halfX,
			-(point.Y + (centerY - halfY) * point.Z) / halfY,
			(point.Y + (centerY + halfY) * point.Z) / halfY
		)
	end
	return frame * CFrame.new(-centerX * distance, -centerY * distance, distance)
end

function StageFraming.boundsCamera(
	reference: CFrame,
	minimum: Vector3,
	maximum: Vector3,
	position: Vector2,
	size: Vector2,
	viewport: Vector2,
	fov: number,
	viewTarget: Vector3?
): CFrame
	local points = StageFraming.boxPoints(CFrame.identity, minimum, maximum)
	return StageFraming.pointsCamera(reference, points, position, size, viewport, fov, viewTarget)
end

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
