--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrailCosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("TrailCosmetics"))

-- Constructs one procedural trail cosmetic on a rendered ball and returns
-- the sole cleanup/enable handle for every generated instance.

local TrailVisuals = {}

export type Handle = {
	setEnabled: (self: Handle, enabled: boolean) -> (),
	destroy: (self: Handle) -> (),
}

local function colorSequence(colors: { Color3 }): ColorSequence
	local keypoints = {}
	local denominator = math.max(#colors - 1, 1)
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / denominator, color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return ColorSequence.new(keypoints)
end

local function addInstance(instances: { Instance }, instance: Instance, parent: Instance)
	instance.Parent = parent
	table.insert(instances, instance)
end

local function buildTrail(ball: BasePart, definition: TrailCosmetics.TrailLayer, index: number, instances: { Instance })
	local top = Instance.new("Attachment")
	top.Name = `TrailCosmeticTop{index}`
	top.Position = Vector3.new(0, definition.Width * 0.5, 0)
	addInstance(instances, top, ball)

	local bottom = Instance.new("Attachment")
	bottom.Name = `TrailCosmeticBottom{index}`
	bottom.Position = Vector3.new(0, -definition.Width * 0.5, 0)
	addInstance(instances, bottom, ball)

	local trail = Instance.new("Trail")
	trail.Name = `TrailCosmeticLayer{index}`
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = colorSequence(definition.Colors)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.72, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Lifetime = definition.Lifetime
	trail.LightEmission = definition.LightEmission
	trail.LightInfluence = 0
	trail.Brightness = definition.Brightness
	trail.FaceCamera = true
	trail.MinLength = 0.08
	trail.Enabled = false
	trail:SetAttribute("ProceduralTrailCosmetic", true)
	addInstance(instances, trail, ball)
end

local function buildEmitter(
	attachment: Attachment,
	definition: TrailCosmetics.EmitterLayer,
	index: number,
	instances: { Instance }
)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = `TrailCosmeticParticles{index}`
	emitter.Texture = definition.Texture
	emitter.Color = colorSequence(definition.Colors)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, definition.Size),
		NumberSequenceKeypoint.new(0.65, definition.Size * 0.72),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rate = definition.Rate
	emitter.Lifetime = definition.Lifetime
	emitter.Speed = definition.Speed
	emitter.SpreadAngle = definition.Spread
	emitter.Drag = definition.Drag
	emitter.Acceleration = definition.Acceleration
	emitter.LightEmission = definition.LightEmission
	emitter.LightInfluence = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = definition.RotationSpeed
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.VelocityInheritance = 0.2
	emitter.LockedToPart = false
	emitter.Enabled = false
	addInstance(instances, emitter, attachment)
end

function TrailVisuals.mount(ball: BasePart, effectId: string): Handle
	local definition = TrailCosmetics[effectId]
	assert(definition, `[TrailVisuals] unknown trail effect {effectId}`)
	local instances = {}
	local effects: { any } = {}

	for index, layer in definition.Trails do
		buildTrail(ball, layer, index, instances)
		table.insert(effects, instances[#instances])
	end
	if #definition.Emitters > 0 then
		local attachment = Instance.new("Attachment")
		attachment.Name = "TrailCosmeticEmitter"
		addInstance(instances, attachment, ball)
		for index, layer in definition.Emitters do
			buildEmitter(attachment, layer, index, instances)
			table.insert(effects, instances[#instances])
		end
	end

	local destroyed = false
	local currentEnabled = false
	local handle = {} :: any
	function handle:setEnabled(enabled: boolean)
		if destroyed or currentEnabled == enabled then
			return
		end
		currentEnabled = enabled
		for _, effect in effects do
			effect.Enabled = enabled
			if not enabled and (effect:IsA("Trail") or effect:IsA("ParticleEmitter")) then
				effect:Clear()
			end
		end
	end
	function handle:destroy()
		if destroyed then
			return
		end
		destroyed = true
		for index = #instances, 1, -1 do
			instances[index]:Destroy()
		end
		table.clear(instances)
		table.clear(effects)
	end
	return handle :: Handle
end

return TrailVisuals
