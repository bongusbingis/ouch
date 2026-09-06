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
	EmissiveStrength: number?,
}

export type VisualDef = {
	Template: string,
	MeshId: number?,
	Size: Vector3?,
	Color: Color3?,
	Material: Enum.Material?,
	SurfaceMaps: SurfaceMaps?,
}

export type VisualTemplateDef = {
	MeshId: number,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	SurfaceMaps: SurfaceMaps?,
}

-- An elimination effect names entries in Config.Audio.Gameplay rather than
-- carrying asset ids. The sounds stay owned by the audio config, so a new
-- effect is an audio entry plus a cosmetic that points at it, and the audio
-- spec validates every id exactly once.
--
-- DodgeballSound and HammerSound are kept as separate fields even though every
-- shipped item currently points both at the same Config.Audio.Gameplay entry
-- (one sound for both weapons). This is the seam for giving a future cosmetic
-- distinct dodgeball/hammer cues without touching this type, EliminationAudio,
-- or GameAudio -- only the item's two field values would differ.
export type ElimEffectDef = {
	DodgeballSound: string,
	HammerSound: string,
}

export type ItemDef = {
	Category: string,
	Rarity: string,
	DisplayName: string,
	EffectId: string?,
	EmoteStyle: string?,
	Thumbnail: string,
	SplatColor: Color3?,
	AlwaysAvailable: boolean?,
	ShopEligible: boolean?,
	SortOrder: number?,
	PreviewColor: Color3?,
	Visual: VisualDef?,
	ElimEffect: ElimEffectDef?,
}

export type DefaultDef = {
	DisplayName: string,
	Rarity: string,
	EffectId: string?,
	EmoteStyle: string?,
	SplatColor: Color3?,
	SortOrder: number?,
	PreviewColor: Color3?,
	Visual: VisualDef?,
	ElimEffect: ElimEffectDef?,
}

local Rarities: { [string]: RarityDef } = {
	Common = { Weight = 70, DupeBonks = 50, DirectBonks = 1000, DisplayOrder = 4 },
	Rare = { Weight = 24, DupeBonks = 150, DirectBonks = 2500, DisplayOrder = 3 },
	Legendary = { Weight = 6, DupeBonks = 400, DirectBonks = 10000, DisplayOrder = 2 },
	Exclusive = { Weight = 0, DupeBonks = 0, DirectBonks = 0, DisplayOrder = 1 },
}

-- TrailAssets and ElimEffectAssets are both "effects" in the storefront but are
-- separate slots on purpose: a ball trail and an elimination effect are
-- unrelated in play, and one slot would make equipping one silently unequip the
-- other.
-- Folder under Assets.Cosmetics holding one authored MeshPart per item in that
-- category. A mesh and its PBR maps cannot be written from a runtime script, so
-- an item's visual can only be authored and cloned -- never built from config.
-- Categories absent here have no per-item mesh.
local VisualFolders = {
	BallAssets = "DodgeBalls",
	HammerAssets = "InflatableHammers",
}

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
		MeshId = 126364964183882,
		Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(248, 248, 248),
		Material = Enum.Material.SmoothPlastic,
	},
	Hammer = {
		MeshId = 95803748037612,
		Size = Vector3.new(1.28, 6.395, 3.156),
		Color = Color3.fromRGB(163, 162, 165),
		Material = Enum.Material.ForceField,
		SurfaceMaps = {
			ColorMapId = 91752383385405,
			MetalnessMapId = 90467888299989,
			NormalMapId = 92363631418304,
			RoughnessMapId = 130600379811137,
		},
	},
}

local Defaults: { [string]: DefaultDef } = {
	EmoteAssets = {
		DisplayName = "Victory Wave",
		Rarity = "Common",
		EmoteStyle = require(script.Parent.Emotes).DefaultStyle,
	},
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
		DisplayName = "Default Bonk",
		Rarity = "Common",
		ElimEffect = {
			DodgeballSound = "DefaultElimination",
			HammerSound = "DefaultElimination",
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

-- `sound` names one Config.Audio.Gameplay entry, played for both weapons; see
-- the ElimEffectDef comment for how a future item would diverge from that.
local function eliminationEffect(rarity: string, displayName: string, sound: string, sortOrder: number): ItemDef
	return {
		Category = "ElimEffectAssets",
		Rarity = rarity,
		DisplayName = displayName,
		Thumbnail = "",
		SortOrder = sortOrder,
		ElimEffect = {
			DodgeballSound = sound,
			HammerSound = sound,
		},
	}
end

local Items: { [string]: ItemDef } = {
	ShowtimeTwirl = {
		Category = "EmoteAssets",
		Rarity = "Exclusive",
		DisplayName = "Confetti Twirl",
		EmoteStyle = "ConfettiTwirl",
		Thumbnail = "",
		ShopEligible = false,
		SortOrder = 10,
	},
	ShowtimeFlex = {
		Category = "EmoteAssets",
		Rarity = "Exclusive",
		DisplayName = "Champion Flex",
		EmoteStyle = "ChampionFlex",
		Thumbnail = "",
		ShopEligible = false,
		SortOrder = 20,
	},
	ShowtimeBounce = {
		Category = "EmoteAssets",
		Rarity = "Exclusive",
		DisplayName = "Party Bounce",
		EmoteStyle = "PartyBounce",
		Thumbnail = "",
		ShopEligible = false,
		SortOrder = 30,
	},
	CharacterColorRed = characterColor("Red", Color3.fromRGB(255, 0, 0), 1),
	CharacterColorPink = characterColor("Pink", Color3.fromRGB(255, 0, 128), 2),
	CharacterColorBlue = characterColor("Blue", Color3.fromRGB(0, 90, 255), 4),
	CharacterColorGreen = characterColor("Green", Color3.fromRGB(0, 200, 80), 5),
	CharacterColorPurple = characterColor("Purple", Color3.fromRGB(160, 60, 255), 6),

	ElimSoundClang = eliminationEffect("Common", "Clang", "ClangElimination", 10),

	ConfettiImpact = {
		Category = "ImpactEffectAssets",
		Rarity = "Common",
		DisplayName = "Confetti Impact",
		Thumbnail = "",
		EffectId = "ConfettiImpact",
		SortOrder = 15,
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
		Rarity = "Rare",
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

	-- Imported from the external particle pack (the "Common" egg-reveal burst),
	-- recolored to the candy palette and reproduced in code via ParticleKit (no
	-- Studio asset); EffectId resolves through the script-effect registry. See
	-- docs/cosmetic-vfx-import.md.
	SugarRush = {
		Category = "ImpactEffectAssets",
		Rarity = "Rare",
		DisplayName = "Sugar Rush",
		Thumbnail = "",
		EffectId = "SugarRush",
		SortOrder = 35,
	},
	Prismatic = {
		Category = "ImpactEffectAssets",
		Rarity = "Exclusive",
		DisplayName = "Prismatic",
		Thumbnail = "",
		EffectId = "Prismatic",
		SortOrder = 90,
	},
	Galaxy = {
		Category = "ImpactEffectAssets",
		Rarity = "Exclusive",
		DisplayName = "Galaxy",
		Thumbnail = "",
		EffectId = "Galaxy",
		SortOrder = 100,
	},
	Starlight = {
		Category = "ImpactEffectAssets",
		Rarity = "Exclusive",
		DisplayName = "Starlight",
		Thumbnail = "",
		EffectId = "Starlight",
		SortOrder = 110,
	},
}

local DodgeballItems = require(script.Parent.DodgeballItems)
local HammerItems = require(script.Parent.HammerItems)

for itemId, def in DodgeballItems do
	assert(Items[itemId] == nil, `[Cosmetics] duplicate item id: {itemId}`)
	Items[itemId] = def
end
for itemId, def in HammerItems do
	assert(Items[itemId] == nil, `[Cosmetics] duplicate item id: {itemId}`)
	Items[itemId] = def
end

return {
	Rarities = Rarities,
	Slots = Slots,
	VisualFolders = VisualFolders,
	Defaults = Defaults,
	Items = Items,
	VisualTemplates = VisualTemplates,
}
