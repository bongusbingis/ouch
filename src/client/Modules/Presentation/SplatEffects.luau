--!strict

-- World-space paint splat for dodgeball eliminations (Elim events carrying a
-- projectileId; hammer elims have none). The effect clone is anchored at the
-- event's impact position instead of the ball, which the sim frees at impact.
-- Splat color derives from the thrower's Equip_BallAssets projection; sim
-- broadcast events can arrive more than once, so effects gate on EventDedup.
-- A Studio-authored Assets.Effects.Splat overrides the code-built prototype
-- template when present (user-directed Instance.new exception while Studio
-- asset access is unavailable); the Splat AudioPlayer is optional and
-- WorldAudio skips it silently until authored.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local WorldAudio = require(script.Parent.WorldAudio)

local SplatEffects = {}

local defaultSplatColor = Cosmetics.Defaults.BallAssets.SplatColor
assert(defaultSplatColor ~= nil, "[SplatEffects] Cosmetics.Defaults.BallAssets.SplatColor must be set")

local seen = EventDedup.new(4096)
local started = false

-- Flash stays authored-white; only the paint emitters take the skin color.
local tintedEmitters = {
	Droplets = true,
	Sheet = true,
}

type EmitterSpec = {
	name: string,
	texture: string,
	burstCount: number,
	speed: NumberRange,
	lifetime: NumberRange,
	spreadAngle: Vector2,
	size: NumberSequence,
	transparency: NumberSequence,
	lightEmission: number,
	acceleration: Vector3?,
	drag: number?,
	rotation: NumberRange?,
	rotSpeed: NumberRange?,
}

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local emitterSpecs: { EmitterSpec } = {
	{
		name = "Droplets",
		texture = SMOKE_TEXTURE,
		burstCount = 28,
		speed = NumberRange.new(25, 45),
		lifetime = NumberRange.new(0.35, 0.7),
		spreadAngle = Vector2.new(40, 40),
		size = NumberSequence.new(0.4, 0.15),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lightEmission = 0.15,
		acceleration = Vector3.new(0, -60, 0),
		drag = 2,
		rotation = NumberRange.new(-180, 180),
		rotSpeed = NumberRange.new(-90, 90),
	},
	{
		name = "Sheet",
		texture = SMOKE_TEXTURE,
		burstCount = 6,
		speed = NumberRange.new(8, 16),
		lifetime = NumberRange.new(0.25, 0.4),
		spreadAngle = Vector2.new(75, 75),
		size = NumberSequence.new(1.2, 2.8),
		transparency = NumberSequence.new(0.15, 1),
		lightEmission = 0.1,
	},
	{
		name = "Flash",
		texture = SPARKLE_TEXTURE,
		burstCount = 1,
		speed = NumberRange.new(0),
		lifetime = NumberRange.new(0.12),
		spreadAngle = Vector2.zero,
		size = NumberSequence.new(3, 5),
		transparency = NumberSequence.new(0.3, 1),
		lightEmission = 1,
	},
}

local function buildPrototypeTemplate(): BasePart
	local part = Instance.new("Part")
	part.Name = "Splat"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)

	for _, spec in emitterSpecs do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = spec.name
		emitter.Enabled = false
		emitter.Texture = spec.texture
		emitter.EmissionDirection = Enum.NormalId.Front
		emitter.Speed = spec.speed
		emitter.Lifetime = spec.lifetime
		emitter.SpreadAngle = spec.spreadAngle
		emitter.Size = spec.size
		emitter.Transparency = spec.transparency
		emitter.LightEmission = spec.lightEmission
		if spec.acceleration then
			emitter.Acceleration = spec.acceleration
		end
		if spec.drag then
			emitter.Drag = spec.drag
		end
		if spec.rotation then
			emitter.Rotation = spec.rotation
		end
		if spec.rotSpeed then
			emitter.RotSpeed = spec.rotSpeed
		end
		emitter:SetAttribute("BurstCount", spec.burstCount)
		emitter.Parent = part
	end

	return part
end

-- FindFirstChild is deliberate here: the Studio asset is optional, and the
-- code-built prototype covers its absence until it can be authored.
local function resolveTemplate(): BasePart
	local effects = ReplicatedStorage:WaitForChild("Assets"):FindFirstChild("Effects")
	local authored = if effects then effects:FindFirstChild("Splat") else nil
	if authored then
		assert(authored:IsA("BasePart"), "[SplatEffects] Assets.Effects.Splat must be a BasePart")
		return authored
	end
	return buildPrototypeTemplate()
end

local template = resolveTemplate()

local function splatColorFor(sourceId: string?): Color3
	local player = PlayerIds.fromId(sourceId)
	if player == nil then
		return defaultSplatColor
	end
	local itemId = player:GetAttribute("Equip_BallAssets") :: string?
	local item = if itemId then Cosmetics.Items[itemId] else nil
	return (item and item.SplatColor) or defaultSplatColor
end

function SplatEffects.onEvent(event: any)
	if event.kind ~= "Elim" or event.projectileId == nil or event.position == nil then
		return
	end
	if not seen.markSeen(event) then
		return
	end

	local position = event.position
	local origin = Vector3.new(position.x, position.y, position.z)
	local direction = event.direction

	local clone = template:Clone()
	clone.CFrame = if direction
		then CFrame.lookAt(origin, origin - Vector3.new(direction.x, direction.y, direction.z))
		else CFrame.new(origin)
	clone.Parent = Workspace.CurrentCamera

	local color = splatColorFor(event.sourceId)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			if tintedEmitters[descendant.Name] then
				descendant.Color = ColorSequence.new(color)
			end
			descendant:Emit(descendant:GetAttribute("BurstCount") or 8)
		end
	end

	WorldAudio.play("Dodgeball", Combat.Splat.SoundName, clone)
	Debris:AddItem(clone, Combat.Splat.Lifetime)
end

function SplatEffects.start()
	if started then
		return
	end
	started = true
end

return SplatEffects
