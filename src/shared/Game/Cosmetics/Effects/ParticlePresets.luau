--!strict

-- Shared emitter vocabulary for cartoony impact cosmetics. Effect modules own
-- their compositions; these constructors keep texture, motion, and timing
-- language consistent across the production roster.

local ParticleKit = require(script.Parent.ParticleKit)

local numberSeq = ParticleKit.numberSeq
local range = ParticleKit.range

local ParticlePresets = {}

local function solid(color: Color3): ColorSequence
	return ColorSequence.new(color)
end

function ParticlePresets.flash(color: Color3, diameter: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://6673021984",
		EmitCount = 1,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 0.18 }, { 0.24, 0.3 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.16, diameter * 1.14 },
			{ 0.31, diameter * 0.94 },
			{ 0.44, diameter * 1.03 },
			{ 0.62, diameter },
			{ 1, diameter },
		}),
		Lifetime = range(0.32),
		Speed = range(0),
		RotSpeed = range(-180, 180),
		LightEmission = 1,
	}
end

function ParticlePresets.ring(color: Color3, diameter: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://15347545896",
		EmitCount = 1,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 0.04 }, { 0.7, 0.12 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.28, diameter * 1.1 },
			{ 0.44, diameter * 0.93 },
			{ 0.58, diameter * 1.03 },
			{ 0.72, diameter },
			{ 1, diameter * 1.06 },
		}),
		Lifetime = range(0.58),
		Speed = range(0),
		Rotation = range(-180, 180),
		LightEmission = 1,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
	}
end

function ParticlePresets.rays(color: Color3, count: number, size: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://13789357218",
		EmitCount = count,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 0.08 }, { 0.62, 0.28 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.18, size * 1.16 },
			{ 0.34, size * 0.9 },
			{ 0.48, size * 1.04 },
			{ 0.68, size },
			{ 1, size * 0.86 },
		}),
		Lifetime = range(0.52, 0.72),
		Speed = range(0),
		Rotation = range(-180, 180),
		RotSpeed = range(-45, 45),
		LightEmission = 1,
	}
end

function ParticlePresets.streaks(color: Color3, count: number, speed: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://5001001365",
		EmitCount = count,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 0.04 }, { 0.72, 0.1 }, { 1, 1 } }),
		Size = numberSeq({ { 0, 0 }, { 0.14, 0.5 }, { 0.28, 0.38 }, { 0.42, 0.44 }, { 0.74, 0.32 }, { 1, 0 } }),
		Lifetime = range(0.42, 0.62),
		Speed = range(speed * 0.68, speed),
		SpreadAngle = Vector2.new(360, 360),
		Rotation = range(90),
		Drag = 3,
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Right,
	}
end

function ParticlePresets.stars(color: Color3, count: number, size: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://15424657493",
		EmitCount = count,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 1 }, { 0.08, 0.02 }, { 0.78, 0.08 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.16, size * 1.17 },
			{ 0.3, size * 0.91 },
			{ 0.43, size * 1.04 },
			{ 0.72, size * 0.9 },
			{ 1, 0 },
		}),
		Lifetime = range(0.62, 0.82),
		Speed = range(6, 15),
		SpreadAngle = Vector2.new(360, 360),
		Rotation = range(-180, 180),
		RotSpeed = range(-220, 220),
		Drag = 4,
		LightEmission = 1,
	}
end

function ParticlePresets.motes(color: Color3, count: number, size: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://13718068134",
		EmitCount = count,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 0.12 }, { 0.72, 0.22 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.16, size * 1.14 },
			{ 0.3, size * 0.92 },
			{ 0.44, size * 1.03 },
			{ 0.74, size * 0.82 },
			{ 1, 0 },
		}),
		Lifetime = range(0.58, 0.82),
		Speed = range(5, 12),
		SpreadAngle = Vector2.new(360, 360),
		Rotation = range(-180, 180),
		RotSpeed = range(-160, 160),
		Drag = 4,
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Right,
	}
end

function ParticlePresets.smoke(color: Color3, count: number, size: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://13712000835",
		EmitCount = count,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 1 }, { 0.12, 0.18 }, { 0.7, 0.38 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.2, size * 1.1 },
			{ 0.36, size * 0.9 },
			{ 0.5, size * 1.03 },
			{ 0.72, size },
			{ 1, size * 1.08 },
		}),
		Lifetime = range(0.58, 0.86),
		Speed = range(1.5, 4),
		SpreadAngle = Vector2.new(360, 360),
		Rotation = range(-180, 180),
		RotSpeed = range(-35, 35),
		Drag = 3,
		LightEmission = 0.35,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
	}
end

function ParticlePresets.debris(color: Color3, count: number, size: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://12780347743",
		EmitCount = count,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 1 }, { 0.08, 0.03 }, { 0.8, 0.12 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.18, size * 1.16 },
			{ 0.32, size * 0.9 },
			{ 0.46, size * 1.04 },
			{ 0.75, size * 0.82 },
			{ 1, size * 0.55 },
		}),
		Lifetime = range(0.48, 0.72),
		Speed = range(5, 11),
		SpreadAngle = Vector2.new(360, 360),
		Rotation = range(-180, 180),
		RotSpeed = range(-180, 180),
		Drag = 2,
		LightEmission = 0.8,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
	}
end

function ParticlePresets.crescents(color: Color3, count: number, size: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://14751068605",
		EmitCount = count,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 1 }, { 0.1, 0.04 }, { 0.78, 0.18 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.2, size * 1.13 },
			{ 0.36, size * 0.9 },
			{ 0.5, size * 1.03 },
			{ 0.72, size },
			{ 1, size * 1.08 },
		}),
		Lifetime = range(0.46, 0.68),
		Speed = range(2.5, 6),
		SpreadAngle = Vector2.new(360, 360),
		Rotation = range(-180, 180),
		RotSpeed = range(-120, 120),
		LightEmission = 1,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
	}
end

function ParticlePresets.flare(color: Color3, size: number, rotation: number): ParticleKit.EmitterSpec
	return {
		Texture = "rbxassetid://11299782591",
		EmitCount = 1,
		Color = solid(color),
		Transparency = numberSeq({ { 0, 1 }, { 0.08, 0.01 }, { 1, 1 } }),
		Size = numberSeq({
			{ 0, 0 },
			{ 0.14, size * 1.2 },
			{ 0.29, size * 0.84 },
			{ 0.43, size * 1.05 },
			{ 0.68, size * 0.78 },
			{ 1, 0 },
		}),
		Lifetime = range(0.18, 0.26),
		Speed = range(0),
		Rotation = range(rotation),
		LightEmission = 1,
	}
end

return ParticlePresets
