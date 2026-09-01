--!strict

-- Lobby inventory grouping, card colors, and viewport framing.

return {
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
				{ Id = "TRAILS", Category = "TrailAssets" },
				{ Id = "IMPACTS", Category = "ImpactEffectAssets" },
				{ Id = "ELIMINATION SOUNDS", Category = "ElimEffectAssets" },
			},
		},
		{
			Id = "EMOTES",
			Sections = {
				{ Id = "EMOTES", Category = "EmoteAssets" },
			},
		},
	},

	RarityColors = {
		Common = Color3.fromRGB(97, 255, 237),
		Rare = Color3.fromRGB(255, 211, 51),
		Legendary = Color3.fromRGB(242, 24, 76),
		Exclusive = Color3.fromRGB(209, 18, 252),
	},

	Viewport = {
		CharacterColor = {
			CameraOffset = Vector3.new(0, 0.4, 7.5),
			TargetOffset = Vector3.new(0, 0.25, 0),
			Scale = 0.65,
			RotationDegrees = 180,
			SpinDegreesPerSecond = 8,
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
		-- Script effects and elimination sounds use InventoryPreview's static badges.
		-- TrailAssets stays out of Tabs until it has a preview.
	},
}
