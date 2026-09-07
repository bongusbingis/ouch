--!strict

-- Builds a code-defined ParticleEmitter effect from a data spec and one-shot
-- bursts it at a world point, so an authored Studio particle pack can be
-- reproduced from its dumped properties without a Studio .rbxl template. The
-- emitter properties are the data; the one-shot contract (create on a transient
-- anchor at the impact point, Emit once with each emitter's EmitCount, then
-- Debris-clear the anchor) matches CosmeticEffectFactory.playInstance.

local Debris = game:GetService("Debris")

local Runtime = require(script.Parent.Runtime)

local ParticleKit = {}

export type Context = {
	position: Vector3,
	direction: Vector3?,
	scale: number?,
	scope: Runtime.Scope?,
}

export type EmitterSpec = {
	Texture: string,
	EmitCount: number,
	Color: ColorSequence?,
	Transparency: NumberSequence?,
	Size: NumberSequence?,
	Lifetime: NumberRange?,
	Speed: NumberRange?,
	Rotation: NumberRange?,
	RotSpeed: NumberRange?,
	SpreadAngle: Vector2?,
	Acceleration: Vector3?,
	Drag: number?,
	LightEmission: number?,
	LightInfluence: number?,
	EmissionDirection: Enum.NormalId?,
	FlipbookLayout: Enum.ParticleFlipbookLayout?,
}

export type EffectSpec = {
	emitters: { EmitterSpec },
}

export type ScriptEffect = {
	play: (context: any) -> (),
}

local ANCHOR_NAME = "ParticleKitAnchor"
local MIN_LIFETIME = 0.1

-- Terse constructors so a dumped `t:value` / `t:[r,g,b]` keypoint list transcribes
-- directly into the sequence datatypes the emitter properties expect.
function ParticleKit.colorSeq(points: { { number } }): ColorSequence
	local keypoints = table.create(#points)
	for index, point in points do
		keypoints[index] = ColorSequenceKeypoint.new(point[1], Color3.fromRGB(point[2], point[3], point[4]))
	end
	return ColorSequence.new(keypoints)
end

function ParticleKit.numberSeq(points: { { number } }): NumberSequence
	local keypoints = table.create(#points)
	for index, point in points do
		keypoints[index] = NumberSequenceKeypoint.new(point[1], point[2])
	end
	return NumberSequence.new(keypoints)
end

function ParticleKit.range(min: number, max: number?): NumberRange
	return NumberRange.new(min, max or min)
end

local function scaledSize(size: NumberSequence, factor: number): NumberSequence
	if factor == 1 then
		return size
	end
	local keypoints = table.create(#size.Keypoints)
	for index, keypoint in size.Keypoints do
		keypoints[index] = NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * factor)
	end
	return NumberSequence.new(keypoints)
end

local function anchorAt(context: Context): BasePart
	local part = Instance.new("Part")
	part.Name = ANCHOR_NAME
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = if context.direction
		then CFrame.lookAt(context.position, context.position - context.direction)
		else CFrame.new(context.position)
	Runtime.mount(part, context.scope)
	return part
end

local function buildEmitter(spec: EmitterSpec, parent: BasePart, scale: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.Texture
	-- One-shot: a left-Enabled emitter would free-run for the anchor's lifetime.
	emitter.Enabled = false
	if spec.Color then
		emitter.Color = spec.Color
	end
	if spec.Transparency then
		emitter.Transparency = spec.Transparency
	end
	if spec.Size then
		emitter.Size = scaledSize(spec.Size, scale)
	end
	if spec.Lifetime then
		emitter.Lifetime = spec.Lifetime
	end
	if spec.Speed then
		emitter.Speed = spec.Speed
	end
	if spec.Rotation then
		emitter.Rotation = spec.Rotation
	end
	if spec.RotSpeed then
		emitter.RotSpeed = spec.RotSpeed
	end
	if spec.SpreadAngle then
		emitter.SpreadAngle = spec.SpreadAngle
	end
	if spec.Acceleration then
		emitter.Acceleration = spec.Acceleration
	end
	-- 0 is a meaningful value for these, so only nil is skipped (0 is truthy in Luau).
	if spec.Drag then
		emitter.Drag = spec.Drag
	end
	if spec.LightEmission then
		emitter.LightEmission = spec.LightEmission
	end
	if spec.LightInfluence then
		emitter.LightInfluence = spec.LightInfluence
	end
	if spec.EmissionDirection then
		emitter.EmissionDirection = spec.EmissionDirection
	end
	if spec.FlipbookLayout then
		emitter.FlipbookLayout = spec.FlipbookLayout
	end
	emitter.Parent = parent
	return emitter
end

function ParticleKit.play(spec: EffectSpec, context: Context)
	if context.scope and context.scope.destroyed then
		return
	end
	local scale = math.clamp(context.scale or 1, 0.25, 2.5)
	local anchor = anchorAt(context)
	local longest = 0
	for _, emitterSpec in spec.emitters do
		local emitter = buildEmitter(emitterSpec, anchor, scale)
		longest = math.max(longest, emitter.Lifetime.Max)
		emitter:Emit(Runtime.scaledCount(emitterSpec.EmitCount, "Secondary"))
	end
	Debris:AddItem(anchor, math.max(longest, MIN_LIFETIME) + 0.25)
end

function ParticleKit.effect(spec: EffectSpec): ScriptEffect
	return {
		play = function(context: any)
			ParticleKit.play(spec, context)
		end,
	}
end

return ParticleKit
