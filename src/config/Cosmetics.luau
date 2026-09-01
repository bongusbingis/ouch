--!strict

-- Cosmetic catalog and the visual definitions shared by every place.

export type RarityDef = {
	Weight: number,
	DupeBonks: number,
	DirectBonks: number,
	DisplayOrder: number,
}

export type SurfaceMaps = {
	ColorMapId: number?,
	MetalnessMapId: number?,
	NormalMapId: number?,
	RoughnessMapId: number?,
}

export type VisualDef = {
	Template: string,
	Color: Color3?,
	TextureId: number?,
}

export type VisualTemplateDef = {
	CarrierName: string,
	MeshId: number,
	SurfaceMaps: SurfaceMaps?,
}

-- An elimination effect names entries in Config.Audio.Gameplay rather than
-- carrying asset ids. The sounds stay owned by the audio config, so a new
-- effect is an audio entry plus a cosmetic that points at it, and the audio
-- spec validates every id exactly once.
export type ElimEffectDef = {
	DodgeballSound: string,
	HammerSound: string,
}

export type ItemDef = {
	Category: string,
	Rarity: string,
	DisplayName: string,
	EffectId: string?,
	Thumbnail: string,
	SplatColor: Color3?,
	AlwaysAvailable: boolean?,
	SortOrder: number?,
	PreviewColor: Color3?,
	Visual: VisualDef?,
	ElimEffect: ElimEffectDef?,
}

export type DefaultDef = {
	DisplayName: string,
	Rarity: string,
	EffectId: string?,
	SplatColor: Color3?,
	SortOrder: number?,
	PreviewColor: Color3?,
	Visual: VisualDef?,
	ElimEffect: ElimEffectDef?,
}

local Rarities: { [string]: RarityDef } = {
	Common = { Weight = 70, DupeBonks = 50, DirectBonks = 1200, DisplayOrder = 4 },
	Rare = { Weight = 24, DupeBonks = 150, DirectBonks = 3500, DisplayOrder = 3 },
	Legendary = { Weight = 6, DupeBonks = 400, DirectBonks = 12000, DisplayOrder = 2 },
	Exclusive = { Weight = 0, DupeBonks = 0, DirectBonks = 0, DisplayOrder = 1 },
}

-- TrailAssets and ElimEffectAssets are both "effects" in the storefront but are
-- separate slots on purpose: a ball trail and an elimination effect are
-- unrelated in play, and one slot would make equipping one silently unequip the
-- other.
local Slots = {
	BallAssets = true,
	HammerAssets = true,
	TrailAssets = true,
	ElimEffectAssets = true,
	ImpactEffectAssets = true,
	EmoteAssets = true,
	CostumeAssets = true,
	CharacterColor = true,
}

local VisualTemplates: { [string]: VisualTemplateDef } = {
	Dodgeball = {
		CarrierName = "DodgeballBase",
		MeshId = 126364964183882,
	},
	Hammer = {
		CarrierName = "HammerBase",
		MeshId = 95803748037612,
		SurfaceMaps = {
			ColorMapId = 91752383385405,
			MetalnessMapId = 90467888299989,
			NormalMapId = 92363631418304,
			RoughnessMapId = 130600379811137,
		},
	},
}

local Defaults: { [string]: DefaultDef } = {
	BallAssets = {
		DisplayName = "Default Dodgeball",
		Rarity = "Common",
		SplatColor = Color3.fromRGB(205, 65, 55),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(151, 0, 0),
		},
	},
	HammerAssets = {
		DisplayName = "Default Hammer",
		Rarity = "Common",
		Visual = {
			Template = "Hammer",
		},
	},
	ElimEffectAssets = {
		DisplayName = "Default Splat",
		Rarity = "Common",
		ElimEffect = {
			DodgeballSound = "DodgeballElimination",
			HammerSound = "HammerElimination",
		},
	},
	-- Config.CosmeticEffects binds this EffectId to the events that fire it.
	ImpactEffectAssets = {
		DisplayName = "Default Impact",
		Rarity = "Common",
		EffectId = "DefaultImpact",
	},
	CharacterColor = {
		DisplayName = "Cyan",
		Rarity = "Common",
		SortOrder = 3,
		PreviewColor = Color3.fromRGB(0, 255, 255),
	},
}

local function ballAsset(rarity: string, displayName: string, color: Color3, splatColor: Color3): ItemDef
	return {
		Category = "BallAssets",
		Rarity = rarity,
		DisplayName = displayName,
		Thumbnail = "",
		SplatColor = splatColor,
		Visual = {
			Template = "Dodgeball",
			Color = color,
		},
	}
end

local function characterColor(displayName: string, color: Color3, sortOrder: number): ItemDef
	return {
		Category = "CharacterColor",
		Rarity = "Common",
		DisplayName = displayName,
		Thumbnail = "",
		AlwaysAvailable = true,
		SortOrder = sortOrder,
		PreviewColor = color,
	}
end

local Items: { [string]: ItemDef } = {
	CharacterColorRed = characterColor("Red", Color3.fromRGB(255, 0, 0), 1),
	CharacterColorPink = characterColor("Pink", Color3.fromRGB(255, 0, 128), 2),
	CharacterColorBlue = characterColor("Blue", Color3.fromRGB(0, 90, 255), 4),
	CharacterColorGreen = characterColor("Green", Color3.fromRGB(0, 200, 80), 5),
	CharacterColorPurple = characterColor("Purple", Color3.fromRGB(160, 60, 255), 6),

	BallRed = ballAsset("Common", "Red Ball", Color3.fromRGB(151, 0, 0), Color3.fromRGB(235, 60, 60)),
	BallBlue = ballAsset("Common", "Blue Ball", Color3.fromRGB(13, 105, 172), Color3.fromRGB(65, 120, 235)),
	BallWhite = ballAsset("Common", "White Ball", Color3.fromRGB(248, 248, 248), Color3.fromRGB(240, 240, 240)),
	BallBlack = ballAsset("Common", "Black Ball", Color3.fromRGB(17, 17, 17), Color3.fromRGB(45, 45, 45)),
	BallOrange = ballAsset("Rare", "Orange Ball", Color3.fromRGB(255, 102, 0), Color3.fromRGB(240, 140, 40)),
	BallGreen = ballAsset("Rare", "Green Ball", Color3.fromRGB(52, 142, 64), Color3.fromRGB(90, 200, 80)),
	BallPink = ballAsset("Rare", "Pink Ball", Color3.fromRGB(255, 102, 204), Color3.fromRGB(240, 120, 190)),
	BallPurple = ballAsset("Legendary", "Purple Ball", Color3.fromRGB(98, 37, 209), Color3.fromRGB(150, 80, 220)),
	BallYellow = ballAsset("Legendary", "Yellow Ball", Color3.fromRGB(255, 255, 0), Color3.fromRGB(240, 210, 60)),

	ConfettiImpact = {
		Category = "ImpactEffectAssets",
		Rarity = "Rare",
		DisplayName = "Confetti Impact",
		Thumbnail = "",
		EffectId = "ConfettiImpact",
	},
	StarPop = {
		Category = "ImpactEffectAssets",
		Rarity = "Common",
		DisplayName = "Star Pop",
		Thumbnail = "",
		EffectId = "StarPop",
		SortOrder = 10,
	},
	FoamPoof = {
		Category = "ImpactEffectAssets",
		Rarity = "Common",
		DisplayName = "Foam Poof",
		Thumbnail = "",
		EffectId = "FoamPoof",
		SortOrder = 20,
	},
	JellySplash = {
		Category = "ImpactEffectAssets",
		Rarity = "Rare",
		DisplayName = "Jelly Splash",
		Thumbnail = "",
		EffectId = "JellySplash",
		SortOrder = 30,
	},
	PartyPopper = {
		Category = "ImpactEffectAssets",
		Rarity = "Rare",
		DisplayName = "Party Popper",
		Thumbnail = "",
		EffectId = "PartyPopper",
		SortOrder = 40,
	},
	ComicBonk = {
		Category = "ImpactEffectAssets",
		Rarity = "Legendary",
		DisplayName = "Comic Bonk",
		Thumbnail = "",
		EffectId = "ComicBonk",
		SortOrder = 50,
	},
	CandyCrash = {
		Category = "ImpactEffectAssets",
		Rarity = "Legendary",
		DisplayName = "Candy Crash",
		Thumbnail = "",
		EffectId = "CandyCrash",
		SortOrder = 60,
	},
	BubbleBurst = {
		Category = "ImpactEffectAssets",
		Rarity = "Legendary",
		DisplayName = "Bubble Burst",
		Thumbnail = "",
		EffectId = "BubbleBurst",
		SortOrder = 70,
	},
	RoyalParty = {
		Category = "ImpactEffectAssets",
		Rarity = "Legendary",
		DisplayName = "Royal Party",
		Thumbnail = "",
		EffectId = "RoyalParty",
		SortOrder = 80,
	},
}

return {
	Rarities = Rarities,
	Slots = Slots,
	Defaults = Defaults,
	Items = Items,
	VisualTemplates = VisualTemplates,
}
