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
	BallSkin = true,
	HammerSkin = true,
	Trail = true,
	Emote = true,
	Costume = true,
}

local CategoryFolders = {
	BallSkin = "BallSkins",
	HammerSkin = "HammerSkins",
	Trail = "Trails",
	Emote = "Emotes",
	Costume = "Costumes",
}

local function ballSkin(displayName: string, assetName: string): ItemDef
	return {
		Category = "BallSkin",
		Rarity = "Common",
		DisplayName = displayName,
		AssetName = assetName,
		Thumbnail = "",
	}
end

local Items: { [string]: ItemDef } = {
	BallRed = ballSkin("Red Ball", "RedDodgeball"),
	BallBlue = ballSkin("Blue Ball", "BlueDodgeball"),
	BallWhite = ballSkin("White Ball", "WhiteDodgeball"),
	BallBlack = ballSkin("Black Ball", "BlackDodgeball"),
	BallOrange = ballSkin("Orange Ball", "OrangeDodgeball"),
	BallGreen = ballSkin("Green Ball", "GreenDodgeball"),
	BallPink = ballSkin("Pink Ball", "PinkDodgeball"),
	BallPurple = ballSkin("Purple Ball", "PurpleDodgeball"),
	BallYellow = ballSkin("Yellow Ball", "YellowDodgeball"),
}

return {
	Rarities = Rarities,
	Slots = Slots,
	CategoryFolders = CategoryFolders,
	Items = Items,
}
