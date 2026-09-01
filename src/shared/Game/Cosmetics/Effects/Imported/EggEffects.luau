--!strict

-- Code-built reproductions of the external pack's egg-reveal bursts, transcribed
-- from the property dump via ParticleKit. Every rarity shares one 9-emitter
-- geometry and differs only by color, so the geometry is authored once and the
-- color is a parameter. SugarRush uses that celebratory geometry; the exclusive
-- cosmetics use independent compositions so color is not their only identity.

local Palette = require(script.Parent.Parent.Palette)
local ParticleKit = require(script.Parent.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.Parent.ParticlePresets)

local numberSeq = ParticleKit.numberSeq
local range = ParticleKit.range

local function solid(c: Color3): ColorSequence
	return ColorSequence.new(c)
end

type ColorMap = {
	Dust: Color3,
	Light: Color3,
	Rays: Color3,
	Shockwave: Color3,
	SmallStripes: Color3,
	Star: Color3,
	HorizontalFlare: Color3,
	Light2: Color3,
	VerticalFlare: Color3,
}

local function mono(c: Color3): ColorMap
	return {
		Dust = c,
		Light = c,
		Rays = c,
		Shockwave = c,
		SmallStripes = c,
		Star = c,
		HorizontalFlare = c,
		Light2 = c,
		VerticalFlare = c,
	}
end

local function eggEmitters(colors: ColorMap): { ParticleKit.EmitterSpec }
	return {
		{
			Texture = "rbxassetid://13718068134",
			EmitCount = 20,
			Color = solid(colors.Dust),
			Transparency = numberSeq({ { 0, 0.08 }, { 0.75, 0.15 }, { 1, 1 } }),
			Size = numberSeq({
				{ 0, 0 },
				{ 0.14, 0.48 },
				{ 0.28, 0.37 },
				{ 0.42, 0.44 },
				{ 0.62, 0.16 },
				{ 0.78, 0.38 },
				{ 1, 0 },
			}),
			Lifetime = range(0.75, 1),
			Speed = range(10, 20),
			SpreadAngle = Vector2.new(360, 360),
			Rotation = range(-180, 180),
			RotSpeed = range(-250, 250),
			Drag = 5,
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Right,
		},
		{
			Texture = "rbxassetid://6673021984",
			EmitCount = 1,
			Color = solid(colors.Light),
			Transparency = numberSeq({ { 0, 0.3 }, { 0.28, 0.45 }, { 1, 1 } }),
			Size = numberSeq({ { 0, 0 }, { 0.15, 14.2 }, { 0.3, 11.4 }, { 0.44, 12.9 }, { 0.62, 12.5 }, { 1, 13 } }),
			Lifetime = range(0.9),
			Speed = range(0),
			RotSpeed = range(360),
			LightEmission = 1,
		},
		{
			Texture = "rbxassetid://13789357218",
			EmitCount = 12,
			Color = solid(colors.Rays),
			Transparency = numberSeq({ { 0, 0.08 }, { 0.65, 0.25 }, { 1, 1 } }),
			Size = numberSeq({ { 0, 0 }, { 0.18, 5.9 }, { 0.34, 4.65 }, { 0.48, 5.4 }, { 0.68, 5.2 }, { 1, 5.7 } }),
			Lifetime = range(0.75, 1),
			Speed = range(0),
			Rotation = range(-180, 180),
			RotSpeed = range(-50, 50),
			LightEmission = 1,
		},
		{
			Texture = "rbxassetid://15347545896",
			EmitCount = 1,
			Color = solid(colors.Shockwave),
			Transparency = numberSeq({ { 0, 0.05 }, { 0.75, 0.12 }, { 1, 1 } }),
			Size = numberSeq({ { 0, 0 }, { 0.28, 8.3 }, { 0.44, 6.95 }, { 0.58, 7.75 }, { 0.72, 7.5 }, { 1, 8 } }),
			Lifetime = range(1),
			Speed = range(0),
			SpreadAngle = Vector2.new(5, 5),
			Rotation = range(-360, 360),
			LightEmission = 1,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		},
		{
			Texture = "rbxassetid://5001001365",
			EmitCount = 15,
			Color = solid(colors.SmallStripes),
			Transparency = numberSeq({ { 0, 0.05 }, { 0.75, 0.1 }, { 1, 1 } }),
			Size = numberSeq({ { 0, 0 }, { 0.14, 0.44 }, { 0.28, 0.34 }, { 0.42, 0.39 }, { 0.74, 0.3 }, { 1, 0 } }),
			Lifetime = range(0.5, 0.75),
			Speed = range(6.75, 11.25),
			SpreadAngle = Vector2.new(360, 360),
			Rotation = range(90),
			Drag = 4,
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Right,
		},
		{
			Texture = "rbxassetid://15424657493",
			EmitCount = 15,
			Color = solid(colors.Star),
			Transparency = numberSeq({ { 0, 1 }, { 0.1, 0.01 }, { 1, 1 } }),
			Size = numberSeq({
				{ 0, 0 },
				{ 0.15, 0.96 },
				{ 0.28, 0.74 },
				{ 0.42, 0 },
				{ 0.58, 0.9 },
				{ 0.72, 0.7 },
				{ 0.82, 0.78 },
				{ 1, 0 },
			}),
			Lifetime = range(0.82),
			Speed = range(5, 20),
			SpreadAngle = Vector2.new(360, 360),
			Rotation = range(-180, 180),
			RotSpeed = range(-250, 250),
			Drag = 5,
			LightEmission = 1,
		},
		{
			Texture = "rbxassetid://11299782591",
			EmitCount = 1,
			Color = solid(colors.HorizontalFlare),
			Transparency = numberSeq({ { 0, 1 }, { 0.1, 0.01 }, { 1, 1 } }),
			Size = numberSeq({ { 0, 0 }, { 0.14, 2.65 }, { 0.28, 2 }, { 0.42, 2.3 }, { 0.68, 1.7 }, { 1, 0 } }),
			Lifetime = range(0.18, 0.28),
			Speed = range(0),
			Rotation = range(0),
			LightEmission = 1,
		},
		{
			Texture = "rbxassetid://6673021984",
			EmitCount = 1,
			Color = solid(colors.Light2),
			Transparency = numberSeq({ { 0, 1 }, { 0.45, 0.52 }, { 1, 1 } }),
			Size = numberSeq({ { 0, 0 }, { 0.18, 6.3 }, { 0.34, 5 }, { 0.48, 5.7 }, { 0.72, 2 }, { 1, 0 } }),
			Lifetime = range(0.5),
			Speed = range(0),
			RotSpeed = range(360),
			LightEmission = 1,
		},
		{
			Texture = "rbxassetid://11299782591",
			EmitCount = 1,
			Color = solid(colors.VerticalFlare),
			Transparency = numberSeq({ { 0, 1 }, { 0.1, 0.01 }, { 1, 1 } }),
			Size = numberSeq({ { 0, 0 }, { 0.14, 2.65 }, { 0.28, 2 }, { 0.42, 2.3 }, { 0.68, 1.7 }, { 1, 0 } }),
			Lifetime = range(0.18, 0.28),
			Speed = range(0),
			Rotation = range(90),
			LightEmission = 1,
		},
	}
end

local candy: ColorMap = {
	Dust = Palette.Pink,
	Light = Palette.White,
	Rays = Palette.Gold,
	Shockwave = Palette.Cyan,
	SmallStripes = Palette.HotPink,
	Star = Palette.Gold,
	HorizontalFlare = Palette.White,
	Light2 = Palette.Lavender,
	VerticalFlare = Palette.White,
}

local prismaticEmitters: { ParticleKit.EmitterSpec } = {
	ParticlePresets.flash(Palette.White, 12),
	ParticlePresets.ring(Palette.Cyan, 27),
	ParticlePresets.ring(Palette.Purple, 19),
	ParticlePresets.rays(Palette.Gold, 12, 8),
	ParticlePresets.streaks(Palette.Teal, 14, 20),
	ParticlePresets.stars(Palette.HotPink, 10, 1.15),
	ParticlePresets.flare(Palette.White, 4.2, 0),
	ParticlePresets.flare(Palette.White, 4.2, 90),
}

local galaxyStars: ParticleKit.EmitterSpec = {
	Texture = "rbxassetid://15424657493",
	EmitCount = 24,
	Color = solid(Palette.LightBlue),
	Transparency = numberSeq({ { 0, 1 }, { 0.1, 0.05 }, { 1, 1 } }),
	Size = numberSeq({ { 0, 0 }, { 0.18, 1 }, { 0.34, 0.78 }, { 0.48, 0.9 }, { 0.78, 0.72 }, { 1, 0 } }),
	Lifetime = range(1.1, 1.4),
	Speed = range(1, 5),
	RotSpeed = range(-120, 120),
	Drag = 5,
	SpreadAngle = Vector2.new(360, 360),
	LightEmission = 1,
}

local galaxyEmitters: { ParticleKit.EmitterSpec } = {
	ParticlePresets.flash(Palette.LightBlue, 10.5),
	ParticlePresets.ring(Palette.Purple, 25),
	ParticlePresets.smoke(Palette.Purple, 9, 7),
	ParticlePresets.smoke(Palette.Lavender, 6, 5.2),
	ParticlePresets.motes(Palette.HotPink, 16, 0.5),
	galaxyStars,
	ParticlePresets.flare(Palette.LightBlue, 3.5, 0),
}

local starlightShaft: ParticleKit.EmitterSpec = {
	Texture = "rbxassetid://13789357218",
	EmitCount = 8,
	Color = solid(Palette.Gold),
	Transparency = numberSeq({ { 0, 0.05 }, { 0.2, 0.08 }, { 1, 1 } }),
	Size = numberSeq({ { 0, 0 }, { 0.18, 9.2 }, { 0.34, 7.1 }, { 0.48, 8.3 }, { 0.68, 8 }, { 1, 8.5 } }),
	Lifetime = range(0.7, 1),
	Speed = range(0),
	Rotation = range(0),
	LightEmission = 1,
}

local starlightEmitters: { ParticleKit.EmitterSpec } = {
	ParticlePresets.flash(Palette.White, 12),
	ParticlePresets.ring(Palette.Gold, 27),
	ParticlePresets.rays(Palette.Gold, 14, 9),
	ParticlePresets.stars(Palette.White, 12, 1.2),
	ParticlePresets.flare(Palette.White, 4.5, 0),
	ParticlePresets.flare(Palette.Gold, 4.5, 90),
	starlightShaft,
}

return {
	Common = ParticleKit.effect({ emitters = eggEmitters(mono(Color3.fromRGB(127, 255, 120))) }),
	Epic = ParticleKit.effect({ emitters = eggEmitters(mono(Color3.fromRGB(81, 46, 255))) }),
	Ethereal = ParticleKit.effect({ emitters = eggEmitters(mono(Color3.fromRGB(255, 191, 139))) }),
	SugarRush = ParticleKit.effect({ emitters = eggEmitters(candy) }),
	Prismatic = ParticleKit.effect({ emitters = prismaticEmitters }),
	Galaxy = ParticleKit.effect({ emitters = galaxyEmitters }),
	Starlight = ParticleKit.effect({ emitters = starlightEmitters }),
}
