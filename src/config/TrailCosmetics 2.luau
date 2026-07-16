--!strict

export type TrailLayer = {
	Colors: { Color3 },
	Lifetime: number,
	Width: number,
	LightEmission: number,
	Brightness: number,
}

export type EmitterLayer = {
	Texture: string,
	Colors: { Color3 },
	Rate: number,
	Lifetime: NumberRange,
	Speed: NumberRange,
	Size: number,
	Spread: Vector2,
	Drag: number,
	Acceleration: Vector3,
	LightEmission: number,
	RotationSpeed: NumberRange,
}

export type Definition = {
	DisplayName: string,
	Rarity: string,
	Trails: { TrailLayer },
	Emitters: { EmitterLayer },
}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function rgb(red: number, green: number, blue: number): Color3
	return Color3.fromRGB(red, green, blue)
end

local function trail(colors: { Color3 }, lifetime: number, width: number, emission: number?): TrailLayer
	return {
		Colors = colors,
		Lifetime = lifetime,
		Width = width,
		LightEmission = emission or 0.65,
		Brightness = if emission and emission >= 0.9 then 2 else 1,
	}
end

local function emitter(
	texture: string,
	colors: { Color3 },
	rate: number,
	lifetime: NumberRange,
	speed: NumberRange,
	size: number,
	spread: Vector2?,
	acceleration: Vector3?
): EmitterLayer
	return {
		Texture = texture,
		Colors = colors,
		Rate = rate,
		Lifetime = lifetime,
		Speed = speed,
		Size = size,
		Spread = spread or Vector2.new(18, 18),
		Drag = 2,
		Acceleration = acceleration or Vector3.new(0, 1.5, 0),
		LightEmission = 0.85,
		RotationSpeed = NumberRange.new(-90, 90),
	}
end

local Definitions: { [string]: Definition } = {
	TrailSkyRibbon = {
		DisplayName = "Sky Ribbon",
		Rarity = "Common",
		Trails = { trail({ rgb(75, 185, 255), rgb(205, 245, 255) }, 0.28, 0.72) },
		Emitters = {},
	},
	TrailLimeRush = {
		DisplayName = "Lime Rush",
		Rarity = "Common",
		Trails = { trail({ rgb(80, 255, 95), rgb(225, 255, 80) }, 0.3, 0.68) },
		Emitters = {},
	},
	TrailBubblegum = {
		DisplayName = "Bubblegum Stream",
		Rarity = "Common",
		Trails = { trail({ rgb(255, 95, 205), rgb(165, 105, 255) }, 0.32, 0.76) },
		Emitters = {},
	},
	TrailSunbeam = {
		DisplayName = "Sunbeam",
		Rarity = "Common",
		Trails = { trail({ rgb(255, 235, 70), rgb(255, 145, 35) }, 0.26, 0.7) },
		Emitters = {},
	},
	TrailMintMist = {
		DisplayName = "Mint Mist",
		Rarity = "Common",
		Trails = { trail({ rgb(205, 255, 240), rgb(70, 220, 190) }, 0.36, 0.64) },
		Emitters = {},
	},

	TrailEmberSprint = {
		DisplayName = "Ember Sprint",
		Rarity = "Rare",
		Trails = { trail({ rgb(255, 245, 90), rgb(255, 55, 20) }, 0.4, 0.82, 0.9) },
		Emitters = {
			emitter(
				FIRE,
				{ rgb(255, 225, 70), rgb(255, 45, 15) },
				16,
				NumberRange.new(0.25, 0.45),
				NumberRange.new(1, 3),
				0.42
			),
		},
	},
	TrailOceanSpray = {
		DisplayName = "Ocean Spray",
		Rarity = "Rare",
		Trails = { trail({ rgb(40, 120, 255), rgb(70, 255, 235) }, 0.42, 0.86) },
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(125, 245, 255), rgb(35, 115, 255) },
				14,
				NumberRange.new(0.35, 0.6),
				NumberRange.new(1, 4),
				0.32,
				Vector2.new(28, 16)
			),
		},
	},
	TrailToxicPop = {
		DisplayName = "Toxic Pop",
		Rarity = "Rare",
		Trails = { trail({ rgb(195, 255, 20), rgb(35, 170, 45) }, 0.45, 0.8, 0.8) },
		Emitters = {
			emitter(
				SMOKE,
				{ rgb(205, 255, 40), rgb(60, 125, 35) },
				12,
				NumberRange.new(0.45, 0.75),
				NumberRange.new(0.5, 2),
				0.5,
				Vector2.new(35, 35),
				Vector3.new(0, 2.5, 0)
			),
		},
	},
	TrailCandyComet = {
		DisplayName = "Candy Comet",
		Rarity = "Rare",
		Trails = { trail({ rgb(255, 75, 190), rgb(85, 210, 255) }, 0.4, 0.9, 0.9) },
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(255, 115, 210), rgb(100, 225, 255) },
				18,
				NumberRange.new(0.3, 0.55),
				NumberRange.new(1, 3),
				0.38
			),
		},
	},
	TrailFrostShards = {
		DisplayName = "Frost Shards",
		Rarity = "Rare",
		Trails = { trail({ rgb(235, 255, 255), rgb(80, 155, 255) }, 0.48, 0.78, 0.95) },
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(255, 255, 255), rgb(95, 180, 255) },
				13,
				NumberRange.new(0.4, 0.7),
				NumberRange.new(1, 3),
				0.3,
				Vector2.new(20, 30),
				Vector3.new(0, -1, 0)
			),
		},
	},

	TrailSolarFlare = {
		DisplayName = "Solar Flare",
		Rarity = "Legendary",
		Trails = {
			trail({ rgb(255, 255, 180), rgb(255, 75, 15) }, 0.58, 1.05, 1),
			trail({ rgb(255, 245, 75), rgb(255, 25, 5) }, 0.3, 0.48, 1),
		},
		Emitters = {
			emitter(
				FIRE,
				{ rgb(255, 250, 145), rgb(255, 45, 5) },
				24,
				NumberRange.new(0.35, 0.65),
				NumberRange.new(2, 5),
				0.58
			),
			emitter(
				SPARKLES,
				{ rgb(255, 255, 210), rgb(255, 145, 20) },
				10,
				NumberRange.new(0.5, 0.9),
				NumberRange.new(2, 6),
				0.24
			),
		},
	},
	TrailVoidRift = {
		DisplayName = "Void Rift",
		Rarity = "Legendary",
		Trails = {
			trail({ rgb(10, 5, 25), rgb(145, 20, 255) }, 0.65, 1.1, 0.8),
			trail({ rgb(235, 70, 255), rgb(30, 0, 65) }, 0.38, 0.42, 1),
		},
		Emitters = {
			emitter(
				SMOKE,
				{ rgb(35, 5, 65), rgb(185, 45, 255) },
				20,
				NumberRange.new(0.5, 0.9),
				NumberRange.new(0, 2),
				0.68,
				Vector2.new(45, 45),
				Vector3.new(0, 1, 0)
			),
		},
	},
	TrailAuroraWake = {
		DisplayName = "Aurora Wake",
		Rarity = "Legendary",
		Trails = {
			trail({ rgb(45, 255, 185), rgb(80, 100, 255), rgb(235, 80, 255) }, 0.7, 1.08, 1),
			trail({ rgb(225, 255, 245), rgb(80, 235, 255) }, 0.4, 0.35, 1),
		},
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(145, 255, 220), rgb(175, 100, 255) },
				22,
				NumberRange.new(0.55, 1),
				NumberRange.new(1, 4),
				0.34,
				Vector2.new(35, 25),
				Vector3.new(0, 2, 0)
			),
		},
	},
	TrailThunderRush = {
		DisplayName = "Thunder Rush",
		Rarity = "Legendary",
		Trails = {
			trail({ rgb(245, 255, 255), rgb(45, 135, 255) }, 0.46, 1, 1),
			trail({ rgb(255, 255, 120), rgb(110, 190, 255) }, 0.22, 0.38, 1),
		},
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(255, 255, 210), rgb(80, 160, 255) },
				28,
				NumberRange.new(0.18, 0.42),
				NumberRange.new(3, 8),
				0.22,
				Vector2.new(45, 20)
			),
		},
	},
	TrailDragonfire = {
		DisplayName = "Dragonfire",
		Rarity = "Legendary",
		Trails = {
			trail({ rgb(120, 255, 80), rgb(255, 185, 25), rgb(220, 30, 10) }, 0.62, 1.15, 1),
			trail({ rgb(255, 255, 170), rgb(255, 70, 15) }, 0.34, 0.5, 1),
		},
		Emitters = {
			emitter(
				FIRE,
				{ rgb(150, 255, 75), rgb(255, 45, 5) },
				26,
				NumberRange.new(0.4, 0.75),
				NumberRange.new(2, 6),
				0.62,
				Vector2.new(24, 24),
				Vector3.new(0, 3, 0)
			),
		},
	},

	TrailCelestialPrism = {
		DisplayName = "Celestial Prism",
		Rarity = "Exclusive",
		Trails = {
			trail(
				{ rgb(255, 80, 100), rgb(255, 235, 70), rgb(70, 255, 180), rgb(80, 150, 255), rgb(210, 80, 255) },
				0.85,
				1.25,
				1
			),
			trail({ rgb(255, 255, 255), rgb(120, 235, 255) }, 0.52, 0.5, 1),
			trail({ rgb(255, 210, 250), rgb(255, 255, 255) }, 0.25, 0.2, 1),
		},
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(255, 255, 255), rgb(255, 115, 225), rgb(90, 225, 255) },
				32,
				NumberRange.new(0.55, 1.1),
				NumberRange.new(2, 7),
				0.4,
				Vector2.new(50, 35),
				Vector3.new(0, 2.5, 0)
			),
			emitter(
				SMOKE,
				{ rgb(110, 210, 255), rgb(225, 100, 255) },
				10,
				NumberRange.new(0.8, 1.3),
				NumberRange.new(0, 2),
				0.75,
				Vector2.new(40, 40)
			),
		},
	},
	TrailEventHorizon = {
		DisplayName = "Event Horizon",
		Rarity = "Exclusive",
		Trails = {
			trail({ rgb(0, 0, 0), rgb(90, 0, 145) }, 0.95, 1.35, 0.65),
			trail({ rgb(255, 110, 30), rgb(135, 20, 255) }, 0.62, 0.62, 1),
			trail({ rgb(255, 235, 190), rgb(255, 75, 15) }, 0.3, 0.22, 1),
		},
		Emitters = {
			emitter(
				SMOKE,
				{ rgb(5, 0, 15), rgb(110, 20, 170) },
				24,
				NumberRange.new(0.7, 1.25),
				NumberRange.new(0, 2),
				0.9,
				Vector2.new(55, 55)
			),
			emitter(
				SPARKLES,
				{ rgb(255, 210, 120), rgb(185, 55, 255) },
				16,
				NumberRange.new(0.4, 0.85),
				NumberRange.new(3, 8),
				0.28
			),
		},
	},
	TrailRoyalNebula = {
		DisplayName = "Royal Nebula",
		Rarity = "Exclusive",
		Trails = {
			trail({ rgb(255, 210, 65), rgb(130, 45, 255), rgb(35, 10, 90) }, 0.9, 1.3, 1),
			trail({ rgb(255, 245, 180), rgb(225, 80, 255) }, 0.55, 0.55, 1),
			trail({ rgb(255, 255, 255), rgb(255, 195, 55) }, 0.28, 0.2, 1),
		},
		Emitters = {
			emitter(
				SMOKE,
				{ rgb(80, 20, 145), rgb(240, 85, 255) },
				18,
				NumberRange.new(0.7, 1.2),
				NumberRange.new(0, 2),
				0.85,
				Vector2.new(45, 45),
				Vector3.new(0, 2, 0)
			),
			emitter(
				SPARKLES,
				{ rgb(255, 245, 175), rgb(235, 110, 255) },
				26,
				NumberRange.new(0.45, 0.9),
				NumberRange.new(2, 6),
				0.3
			),
		},
	},
	TrailGlitchSpectrum = {
		DisplayName = "Glitch Spectrum",
		Rarity = "Exclusive",
		Trails = {
			trail({ rgb(0, 255, 235), rgb(255, 0, 185), rgb(255, 245, 0) }, 0.48, 1.25, 1),
			trail({ rgb(255, 255, 255), rgb(0, 80, 255) }, 0.24, 0.58, 1),
			trail({ rgb(255, 30, 30), rgb(40, 255, 155) }, 0.14, 0.2, 1),
		},
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(0, 255, 230), rgb(255, 30, 205) },
				36,
				NumberRange.new(0.18, 0.5),
				NumberRange.new(2, 9),
				0.26,
				Vector2.new(60, 45)
			),
			emitter(
				SMOKE,
				{ rgb(40, 65, 255), rgb(255, 35, 165) },
				12,
				NumberRange.new(0.35, 0.7),
				NumberRange.new(1, 4),
				0.45,
				Vector2.new(55, 35)
			),
		},
	},
	TrailSeraphicWake = {
		DisplayName = "Seraphic Wake",
		Rarity = "Exclusive",
		Trails = {
			trail({ rgb(255, 255, 255), rgb(255, 230, 120) }, 1, 1.4, 1),
			trail({ rgb(125, 220, 255), rgb(255, 255, 255) }, 0.65, 0.68, 1),
			trail({ rgb(255, 250, 190), rgb(255, 255, 255) }, 0.32, 0.24, 1),
		},
		Emitters = {
			emitter(
				SPARKLES,
				{ rgb(255, 255, 255), rgb(255, 225, 115) },
				34,
				NumberRange.new(0.65, 1.2),
				NumberRange.new(2, 7),
				0.38,
				Vector2.new(50, 35),
				Vector3.new(0, 3.5, 0)
			),
			emitter(
				SMOKE,
				{ rgb(195, 240, 255), rgb(255, 250, 205) },
				10,
				NumberRange.new(0.9, 1.4),
				NumberRange.new(0, 1.5),
				0.72,
				Vector2.new(35, 35),
				Vector3.new(0, 2, 0)
			),
		},
	},
}

return Definitions
