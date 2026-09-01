-- Name: WeaponViewport.luau
-- Author: Jack C.
-- Description: Renders an equipped dodgeball or hammer cosmetic as a reusable icon-sized 3D preview.
-- Created: 2026-08-28

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
		if props.Weapon == "Dodgeball" then
			object.Size *= 1.42
			object.CFrame = CFrame.Angles(math.rad(-12), math.rad(24), 0)
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.08, 3.75 / zoom), Vector3.zero)
		else
			object.Size *= 1.1
			object.CFrame = CFrame.Angles(math.rad(-8), math.rad(-24), math.rad(-28))
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 6.8 / zoom), Vector3.zero)
		end
		object.Parent = world
		return function()
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
