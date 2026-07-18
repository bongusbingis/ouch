--!strict

-- Cosmetic catalog. AssetName references a template under
-- ReplicatedStorage.Assets.Cosmetics.<CategoryFolders[Category]>.
-- DisplayName/Thumbnail are for UI rendering (locker/shop later).

local TrailCosmetics = require(script.Parent.TrailCosmetics)

export type RarityDef = {
	Weight: number, -- crate roll weight; 0 = never drops (grant-only)
	DupeCash: number, -- Cash refunded when a crate rolls an owned item
}

export type ItemDef = {
	Category: string, -- equip slot this item occupies
	Rarity: string,
	DisplayName: string,
	AssetName: string?,
	EffectId: string?,
	Thumbnail: string,
	SplatColor: Color3?, -- BallAssets only: tints the elimination splat emitters
}

export type DefaultDef = {
	DisplayName: string,
	AssetName: string,
	SplatColor: Color3?,
}

local Rarities: { [string]: RarityDef } = {
	Common = { Weight = 70, DupeCash = 50 },
	Rare = { Weight = 24, DupeCash = 150 },
	Legendary = { Weight = 6, DupeCash = 400 },
	Exclusive = { Weight = 0, DupeCash = 0 },
}

local Slots = {
	BallAssets = true,
	HammerAssets = true,
	TrailAssets = true,
	EmoteAssets = true,
	CostumeAssets = true,
}

local CategoryFolders = {
	BallAssets = "BallAssets",
	HammerAssets = "HammerAssets",
	TrailAssets = "TrailAssets",
	EmoteAssets = "EmoteAssets",
	CostumeAssets = "CostumeAssets",
}

local Defaults: { [string]: DefaultDef } = {
	BallAssets = {
		DisplayName = "Default Dodgeball",
		AssetName = "DefaultDodgeball",
		SplatColor = Color3.fromRGB(205, 65, 55),
	},
	HammerAssets = {
		DisplayName = "Default Hammer",
		AssetName = "DefaultHammer",
	},
}

local function ballAsset(displayName: string, assetName: string, splatColor: Color3): ItemDef
	return {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = displayName,
		AssetName = assetName,
		Thumbnail = "",
		SplatColor = splatColor,
	}
end

local Items: { [string]: ItemDef } = {
	BallRed = ballAsset("Red Ball", "RedDodgeball", Color3.fromRGB(235, 60, 60)),
	BallBlue = ballAsset("Blue Ball", "BlueDodgeball", Color3.fromRGB(65, 120, 235)),
	BallWhite = ballAsset("White Ball", "WhiteDodgeball", Color3.fromRGB(240, 240, 240)),
	BallBlack = ballAsset("Black Ball", "BlackDodgeball", Color3.fromRGB(45, 45, 45)),
	BallOrange = ballAsset("Orange Ball", "OrangeDodgeball", Color3.fromRGB(240, 140, 40)),
	BallGreen = ballAsset("Green Ball", "GreenDodgeball", Color3.fromRGB(90, 200, 80)),
	BallPink = ballAsset("Pink Ball", "PinkDodgeball", Color3.fromRGB(240, 120, 190)),
	BallPurple = ballAsset("Purple Ball", "PurpleDodgeball", Color3.fromRGB(150, 80, 220)),
	BallYellow = ballAsset("Yellow Ball", "YellowDodgeball", Color3.fromRGB(240, 210, 60)),
}

for itemId, definition in TrailCosmetics do
	Items[itemId] = {
		Category = "TrailAssets",
		Rarity = definition.Rarity,
		DisplayName = definition.DisplayName,
		EffectId = itemId,
		Thumbnail = "",
	}
end

return {
	Rarities = Rarities,
	Slots = Slots,
	CategoryFolders = CategoryFolders,
	Defaults = Defaults,
	Items = Items,
}
