-- Description: Renders cosmetic inventory previews, using shared character appearance and marking effects that open in the live preview scene.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local CosmeticsModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics")
local CosmeticVisualFactory = require(CosmeticsModules:WaitForChild("CosmeticVisualFactory"))
local CharacterAppearance = require(CosmeticsModules:WaitForChild("CharacterAppearance"))
local CelebrationAvatar = require(script.Parent.Arena.CelebrationAvatar)
local PreviewScheduler = require(script.Parent.Parent.Services.PreviewScheduler)

local CandyEffectPreview = require(script.Parent.CandyEffectPreview)

local c = React.createElement

-- Characters (outfit colours and costumes) use the emote avatar's light rig so a
-- body colour renders true (RED and PINK stay distinct instead of both reading
-- maroon under the viewport's dim defaults) and every Backpack figure matches.
local CHARACTER_LIGHT = {
	Ambient = Color3.fromRGB(205, 205, 225),
	LightColor = Color3.fromRGB(255, 246, 230),
	LightDirection = Vector3.new(-1, -1, -1),
}
local function setPivot(object: Model | BasePart, pivot: CFrame)
	if object:IsA("Model") then
		object:PivotTo(pivot)
	else
		object.CFrame = pivot
	end
end

local function update(state, dt: number)
	if GuiService.ReducedMotionEnabled then
		setPivot(state.object, CFrame.Angles(0, state.baseRotation, 0) * state.basePivot)
		return
	end
	state.elapsed += dt
	local spin = math.rad(state.config.SpinDegreesPerSecond) * state.elapsed
	setPivot(state.object, CFrame.Angles(0, state.baseRotation + spin, 0) * state.basePivot)
end

-- A preview that holds one pose needs no place in the update loop at all: it is
-- posed once here and never costs another frame.
local function register(state)
	update(state, 0)
	if state.config.SpinDegreesPerSecond == 0 then
		return nil
	end
	return PreviewScheduler.register(state.viewport, function(dt)
		update(state, dt)
	end, state.config.UpdateHz)
end

local function preparePart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- A still preview rig is never animated, heard or simulated, so the authored
-- character's sounds, animator and joint constraints are cut once into a shared
-- template. Every tile then clones that lighter rig instead of repeating the
-- strip, which is what makes a page full of previews affordable.
local UNUSED_IN_PREVIEW: { [string]: boolean } = {
	AnimationConstraint = true,
	Animator = true,
	BallSocketConstraint = true,
	NoCollisionConstraint = true,
	Sound = true,
}
local previewTemplate: Model? = nil

local function characterPreview(): Model
	local cached = previewTemplate
	if cached == nil then
		local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
		assert(template:IsA("Model"), "[InventoryPreview] Assets.Rigs.CharacterRig must be a Model")
		cached = template:Clone()
		for _, descendant in cached:GetDescendants() do
			if UNUSED_IN_PREVIEW[descendant.ClassName] then
				descendant:Destroy()
			end
		end
		for _, descendant in cached:GetDescendants() do
			if descendant:IsA("BasePart") then
				preparePart(descendant)
			end
		end
		previewTemplate = cached
	end
	return cached:Clone()
end

local function setScale(object: Model | BasePart, scale: number)
	if object:IsA("Model") then
		object:ScaleTo(scale)
	else
		object.Size *= scale
	end
end

-- Poses the object (optional fixed Z tilt) then centres its posed bounding box on
-- the origin. Returns the base pivot and the AABB extent of that posed shape.
local function centerObject(object: Model | BasePart, tiltDegrees: number?): (CFrame, Vector3)
	local tilt = CFrame.Angles(0, 0, math.rad(tiltDegrees or 0))
	if object:IsA("Model") then
		object:PivotTo(tilt)
		local bounds, extent = object:GetBoundingBox()
		object:PivotTo(CFrame.new(-bounds.Position) * object:GetPivot())
		return object:GetPivot(), extent
	end
	object.CFrame = tilt
	local half = object.Size / 2
	local r = tilt.RightVector
	local u = tilt.UpVector
	local l = tilt.LookVector
	local extent = Vector3.new(
		2 * (math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z),
		2 * (math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z),
		2 * (math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z)
	)
	return object.CFrame, extent
end

export type Props = {
	Playing: boolean?,
	Candy: boolean?,
	ItemId: string?,
	Category: string,
	Definition: any,
	ZIndex: number,
	ColorId: string?,
	CostumeId: string?,
	TextColor: Color3?,
	TextStroke: number?,
}

local ViewportPreview = React.memo(function(props: Props)
	local viewportRef = React.useRef(nil)
	local cameraRef = React.useRef(nil)
	local worldRef = React.useRef(nil)
	local config = InventoryConfig.Viewport[props.Category]
	assert(config ~= nil, `[InventoryPreview] no preview config for {props.Category}`)

	React.useEffect(function()
		local viewport: ViewportFrame = viewportRef.current
		local camera: Camera = cameraRef.current
		local world: WorldModel = worldRef.current
		if not viewport or not camera or not world then
			return
		end
		viewport.CurrentCamera = camera
		local object: (Model | BasePart)? = nil
		local unregister: (() -> ())? = nil
		local appearance = nil
		local resize = nil
		local cancelBuild = PreviewScheduler.build(viewport, function()
			local prepared: Model | BasePart
			if props.Category == "CharacterColor" or props.Category == "CostumeAssets" then
				local look = {
					characterColorId = if props.Category == "CharacterColor" then props.ItemId else props.ColorId,
					costumeId = if props.Category == "CostumeAssets" then props.ItemId else props.CostumeId,
				}
				CharacterAppearance.prepare(look)
				prepared = characterPreview()
				object = prepared
				appearance = CharacterAppearance.create(prepared, look)
			else
				prepared = CosmeticVisualFactory.create(props.Category, props.ItemId)
			end
			object = prepared
			setScale(prepared, config.Scale)
			prepared.Parent = world
			local basePivot, extent = centerObject(prepared, config.TiltDegrees)
			local function frameCamera()
				local size = viewport.AbsoluteSize
				local aspect = math.max(size.X, 1) / math.max(size.Y, 1)
				local target = config.TargetOffset
				local radius = Vector2.new(extent.X, extent.Z).Magnitude / 2
				local tangent = math.tan(math.rad(camera.FieldOfView / 2)) * InventoryConfig.ViewportFill
				local distance = math.max((extent.Y / 2 + math.abs(target.Y)) / tangent, radius / (tangent * aspect))
					+ radius
				camera.CFrame = CFrame.lookAt(
					target
						+ config.CameraOffset.Unit
							* distance
							* (if props.Candy and config.TiltDegrees == nil then 0.76 else 1),
					target
				)
			end
			frameCamera()
			resize = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
			unregister = register({
				object = prepared,
				viewport = viewport,
				scroller = viewport:FindFirstAncestorWhichIsA("ScrollingFrame"),
				category = props.Category,
				config = config,
				basePivot = basePivot,
				baseRotation = math.rad(config.RotationDegrees),
				elapsed = 0,
				updateAccumulator = 0,
			})
		end)
		return function()
			cancelBuild()
			if resize then
				resize:Disconnect()
			end
			if unregister then
				unregister()
			end
			if appearance then
				appearance.destroy()
			end
			if object then
				object:Destroy()
			end
			if viewport.CurrentCamera == camera then
				viewport.CurrentCamera = nil
			end
		end
	end, { props.Category, props.ItemId, props.Definition, props.ColorId, props.CostumeId })

	local character = props.Category == "CharacterColor" or props.Category == "CostumeAssets"
	return c("ViewportFrame", {
		ref = viewportRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.475),
		Size = UDim2.fromScale(1, 1),
		Ambient = if character then CHARACTER_LIGHT.Ambient else nil,
		LightColor = if character then CHARACTER_LIGHT.LightColor else nil,
		LightDirection = if character then CHARACTER_LIGHT.LightDirection else nil,
		ZIndex = props.ZIndex,
	}, {
		PreviewCamera = c("Camera", { ref = cameraRef, FieldOfView = InventoryConfig.ViewportFieldOfView }),
		PreviewWorld = c("WorldModel", { ref = worldRef }),
	})
end)

return React.memo(function(props: Props)
	if props.Category == "EmoteAssets" then
		return c(CelebrationAvatar, {
			EmoteId = props.ItemId,
			ColorId = props.ColorId,
			CostumeId = props.CostumeId,
			ZIndex = props.ZIndex,
			Playing = props.Playing,
		})
	end
	if props.Category == "ImpactEffectAssets" or props.Category == "ElimEffectAssets" then
		-- Every surface shows the same designed effect seal, never a bare glyph.
		return c(CandyEffectPreview, props)
	end
	return c(ViewportPreview, props)
end)
