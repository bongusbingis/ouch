-- Description: Renders an equipped dodgeball or hammer cosmetic as a reusable icon-sized 3D preview.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local CosmeticVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)

local c = React.createElement

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- Share of the viewport the cosmetic may fill; the rest is breathing room so rims never touch the crop.
local FILL = 0.94

-- Half extents of the part's rotated bounding box, measured from its eight corners.
local function halfExtents(object: BasePart): Vector3
	local half = object.Size / 2
	local rotation = object.CFrame.Rotation
	local x, y, z = 0, 0, 0
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = rotation:VectorToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				x = math.max(x, math.abs(corner.X))
				y = math.max(y, math.abs(corner.Y))
				z = math.max(z, math.abs(corner.Z))
			end
		end
	end
	return Vector3.new(x, y, z)
end

-- Camera distance that keeps the whole bounding box inside the viewport, however large the mesh.
local function fitDistance(extents: Vector3, fieldOfView: number, aspect: number): number
	local tanV = math.tan(math.rad(fieldOfView / 2))
	local tanH = tanV * math.max(aspect, 0.1)
	return math.max(extents.Y / tanV, extents.X / tanH) / FILL + extents.Z
end

export type Props = {
	Weapon: string,
	ItemId: string?,
	Zoom: number?,
	ZIndex: number?,
}

return function(props: Props)
	local viewportRef = React.useRef(nil)
	local cameraRef = React.useRef(nil)
	local worldRef = React.useRef(nil)

	React.useEffect(function()
		local viewport: ViewportFrame? = viewportRef.current
		local camera: Camera? = cameraRef.current
		local world: WorldModel? = worldRef.current
		if viewport == nil or camera == nil or world == nil then
			return
		end
		viewport.CurrentCamera = camera
		local zoom = math.max(props.Zoom or 1, 0.1)
		local category = if props.Weapon == "Dodgeball" then "BallAssets" else "HammerAssets"
		local object = CosmeticVisualFactory.create(category, props.ItemId)
		prepare(object)
		local baseDistance
		if props.Weapon == "Dodgeball" then
			object.Size *= 1.42
			object.CFrame = CFrame.Angles(math.rad(-12), math.rad(24), 0)
			baseDistance = 3.75
		else
			object.Size *= 1.1
			object.CFrame = CFrame.Angles(math.rad(-8), math.rad(-24), math.rad(-28))
			baseDistance = 6.8
		end
		object.Parent = world
		local extents = halfExtents(object)
		-- Zoom tightens the shot, but never past the point where the mesh would be cropped.
		local function frame()
			local size = viewport.AbsoluteSize
			local aspect = if size.Y > 0 then size.X / size.Y else 1
			local distance = math.max(baseDistance / zoom, fitDistance(extents, camera.FieldOfView, aspect))
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
		end
		frame()
		local sizeConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
		return function()
			sizeConnection:Disconnect()
			if viewport.CurrentCamera == camera then
				viewport.CurrentCamera = nil
			end
			object:Destroy()
		end
	end, { props.Weapon, props.ItemId, props.Zoom })

	return c("ViewportFrame", {
		ref = viewportRef,
		Ambient = Color3.fromRGB(205, 205, 205),
		BackgroundTransparency = 1,
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex or 1,
	}, {
		PreviewCamera = c("Camera", { ref = cameraRef }),
		PreviewWorld = c("WorldModel", { ref = worldRef }),
	})
end
