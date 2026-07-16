--!strict

-- Cosmetic catalog. AssetName references a template under
-- ReplicatedStorage.Assets.Cosmetics.<CategoryFolders[Category]>.
-- DisplayName/Thumbnail are for UI rendering (locker/shop later).

export type RarityDef = {
	Weight: number, -- crate roll weight; 0 = never drops (grant-only)
	DupeCash: number, -- Cash refunded when a crate rolls an owned item
}

export type ItemDef = {
	Category: string, -- equip slot this item occupies
	Rarity: string,
	DisplayName: string,
	AssetName: string,
	Thumbnail: string,
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

local function ballAsset(displayName: string, assetName: string): ItemDef
	return {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = displayName,
		AssetName = assetName,
		Thumbnail = "",
	}
end

local Items: { [string]: ItemDef } = {
	BallRed = ballAsset("Red Ball", "RedDodgeball"),
	BallBlue = ballAsset("Blue Ball", "BlueDodgeball"),
	BallWhite = ballAsset("White Ball", "WhiteDodgeball"),
	BallBlack = ballAsset("Black Ball", "BlackDodgeball"),
	BallOrange = ballAsset("Orange Ball", "OrangeDodgeball"),
	BallGreen = ballAsset("Green Ball", "GreenDodgeball"),
	BallPink = ballAsset("Pink Ball", "PinkDodgeball"),
	BallPurple = ballAsset("Purple Ball", "PurpleDodgeball"),
	BallYellow = ballAsset("Yellow Ball", "YellowDodgeball"),
}

return {
	Rarities = Rarities,
	Slots = Slots,
	CategoryFolders = CategoryFolders,
	Items = Items,
}
