--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Inventory"))
local CosmeticsModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics")
local CosmeticVisualFactory = require(CosmeticsModules:WaitForChild("CosmeticVisualFactory"))
local InventoryTrailPreview = require(script.Parent.InventoryTrailPreview)

local InventoryViewportRenderer = {}

export type Handle = {
	destroy: (self: Handle) -> (),
}

type Entry = {
	itemId: string?,
	category: string,
	definition: any,
}

type PreviewState = {
	object: Model | BasePart,
	category: string,
	config: any,
	basePivot: CFrame,
	baseRotation: number,
	elapsed: number,
	trailPreview: InventoryTrailPreview.Handle?,
}

local UPDATE_INTERVAL = 1 / 30
local activePreviews: { [PreviewState]: boolean } = {}
local animationConnection: RBXScriptConnection? = nil
local animationAccumulator = 0

local function preparePart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function characterPreview(color: Color3): Model
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
	assert(template:IsA("Model"), "[InventoryViewportRenderer] Assets.Rigs.CharacterRig must be a Model")
	local rig = template:Clone()
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			preparePart(descendant)
			if descendant.Transparency < 1 then
				descendant.Color = color
			end
		end
	end
	return rig
end

local function setScale(object: Model | BasePart, scale: number)
	if object:IsA("Model") then
		object:ScaleTo(scale)
	else
		object.Size *= scale
	end
end

local function centerObject(object: Model | BasePart): CFrame
	if object:IsA("Model") then
		object:PivotTo(CFrame.identity)
		local bounds = object:GetBoundingBox()
		object:PivotTo(CFrame.new(-bounds.Position) * object:GetPivot())
		return object:GetPivot()
	end
	object.CFrame = CFrame.identity
	return object.CFrame
end

local function setPivot(object: Model | BasePart, pivot: CFrame)
	if object:IsA("Model") then
		object:PivotTo(pivot)
	else
		object.CFrame = pivot
	end
end

local function updatePreview(state: PreviewState, dt: number)
	state.elapsed += dt
	if state.category == "TrailAssets" then
		local distance = state.config.TravelDistance
		local seconds = state.config.TravelSeconds
		local x = math.sin(state.elapsed * math.pi * 2 / seconds) * distance * 0.5
		setPivot(state.object, CFrame.new(x, 0, 0) * CFrame.Angles(0, state.baseRotation, 0))
		if state.trailPreview then
			state.trailPreview:update(state.elapsed)
		end
	else
		local spin = math.rad(state.config.SpinDegreesPerSecond) * state.elapsed
		setPivot(state.object, CFrame.Angles(0, state.baseRotation + spin, 0) * state.basePivot)
	end
end

local function startAnimationLoop()
	if animationConnection then
		return
	end
	animationConnection = RunService.RenderStepped:Connect(function(dt)
		animationAccumulator += dt
		if animationAccumulator < UPDATE_INTERVAL then
			return
		end
		local step = math.min(animationAccumulator, 0.1)
		animationAccumulator = 0
		for state in activePreviews do
			updatePreview(state, step)
		end
	end)
end

local function removePreview(state: PreviewState)
	activePreviews[state] = nil
	if next(activePreviews) == nil and animationConnection then
		animationConnection:Disconnect()
		animationConnection = nil
		animationAccumulator = 0
	end
end

function InventoryViewportRenderer.mount(viewport: ViewportFrame, entry: Entry): Handle
	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.Parent = viewport
	local world = Instance.new("WorldModel")
	world.Name = "PreviewWorld"
	world.Parent = viewport
	viewport.CurrentCamera = camera

	local config = InventoryConfig.Viewport[entry.category]
	assert(config ~= nil, `[InventoryViewportRenderer] no preview config for {entry.category}`)
	local object: Model | BasePart
	local trailPreview: InventoryTrailPreview.Handle? = nil

	if entry.category == "CharacterColor" then
		local color = entry.definition.PreviewColor
		assert(color ~= nil, "[InventoryViewportRenderer] character colors require PreviewColor")
		object = characterPreview(color)
	elseif entry.category == "TrailAssets" then
		object = CosmeticVisualFactory.create("BallAssets", nil)
		local effectId = entry.definition.EffectId
		assert(effectId ~= nil, "[InventoryViewportRenderer] trail cosmetics require EffectId")
		trailPreview = InventoryTrailPreview.mount(viewport, effectId, config)
	else
		object = CosmeticVisualFactory.create(entry.category, entry.itemId)
	end

	setScale(object, config.Scale)
	object.Parent = world
	local basePivot = centerObject(object)
	local baseRotation = math.rad(config.RotationDegrees)
	local target = config.TargetOffset
	camera.CFrame = CFrame.lookAt(target + config.CameraOffset, target)
	local state: PreviewState = {
		object = object,
		category = entry.category,
		config = config,
		basePivot = basePivot,
		baseRotation = baseRotation,
		elapsed = 0,
		trailPreview = trailPreview,
	}
	updatePreview(state, 0)
	activePreviews[state] = true
	startAnimationLoop()

	local destroyed = false
	local handle = {} :: any
	local destroyingConnection: RBXScriptConnection? = nil
	function handle:destroy()
		if destroyed then
			return
		end
		destroyed = true
		if destroyingConnection then
			destroyingConnection:Disconnect()
			destroyingConnection = nil
		end
		removePreview(state)
		if trailPreview then
			trailPreview:destroy()
		end
		world:Destroy()
		camera:Destroy()
	end
	destroyingConnection = viewport.Destroying:Connect(function()
		handle:destroy()
	end)
	return handle :: Handle
end

return InventoryViewportRenderer
