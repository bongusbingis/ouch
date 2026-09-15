--!strict

-- Lobby inventory grouping, card colors, and viewport framing.

return {
	ItemLabels = {
		BallAssets = "DODGEBALL SKIN",
		HammerAssets = "HAMMER SKIN",
		CostumeAssets = "OUTFIT",
		CharacterColor = "COLOR",
		ImpactEffectAssets = "IMPACT EFFECT",
		ElimEffectAssets = "ELIMINATION SOUND",
		EmoteAssets = "EMOTE",
		TrailAssets = "TRAIL",
	},
	Tabs = {
		{
			Id = "OUTFITS",
			Sections = {
				{ Id = "COLORS", Category = "CharacterColor" },
				{ Id = "OUTFITS", Category = "CostumeAssets" },
			},
		},
		{
			Id = "SKINS",
			Sections = {
				{ Id = "DODGEBALL SKINS", Category = "BallAssets" },
				{ Id = "HAMMER SKINS", Category = "HammerAssets" },
			},
		},
		{
			Id = "EFFECTS",
			Sections = {
				{ Id = "IMPACTS", Category = "ImpactEffectAssets" },
				{ Id = "ELIMINATION EFFECTS", Category = "ElimEffectAssets" },
			},
		},
		{
			Id = "EMOTES",
			Sections = {
				{ Id = "ALL EMOTES", Category = "EmoteAssets" },
			},
		},
	},

	RarityColors = {
		Common = Color3.fromRGB(97, 255, 237),
		Rare = Color3.fromRGB(255, 211, 51),
		Legendary = Color3.fromRGB(242, 24, 76),
		Exclusive = Color3.fromRGB(209, 18, 252),
	},

	ViewportFieldOfView = 45,
	ViewportFill = 0.9,
	WorldPreview = {
		HammerGripAlongLongAxis = -0.4,
	},
	Viewport = {
		CostumeAssets = {
			CameraOffset = Vector3.new(0, 0.3, 8.8),
			TargetOffset = Vector3.new(0, 0.1, 0),
			Scale = 0.65,
			RotationDegrees = 160,
			SpinDegreesPerSecond = 0,
		},
		CharacterColor = {
			CameraOffset = Vector3.new(0, 0.4, 7.5),
			TargetOffset = Vector3.new(0, 0.25, 0),
			Scale = 0.65,
			RotationDegrees = 160,
			SpinDegreesPerSecond = 0,
		},
		BallAssets = {
			CameraOffset = Vector3.new(0, 0, 4.5),
			TargetOffset = Vector3.zero,
			Scale = 1.25,
			RotationDegrees = 0,
			SpinDegreesPerSecond = 22,
		},
		HammerAssets = {
			CameraOffset = Vector3.new(0, 0, 9),
			TargetOffset = Vector3.zero,
			Scale = 0.8,
			RotationDegrees = -20,
			SpinDegreesPerSecond = 12,
		},
	},
}
