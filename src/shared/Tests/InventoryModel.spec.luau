--!strict

local T = require(script.Parent.TestKit)
local InventoryModel = require(script.Parent.Parent.Game.Economy.InventoryModel)

local CATALOG = {
	Slots = {
		BallAssets = true,
		CharacterColor = true,
		EmoteAssets = true,
	},
	Defaults = {
		BallAssets = { DisplayName = "Default Ball", Rarity = "Common" },
		CharacterColor = { DisplayName = "Cyan", Rarity = "Common", SortOrder = 3 },
	},
	Items = {
		Red = {
			Category = "CharacterColor",
			DisplayName = "Red",
			Rarity = "Common",
			AlwaysAvailable = true,
			SortOrder = 1,
		},
		Purple = {
			Category = "CharacterColor",
			DisplayName = "Purple",
			Rarity = "Common",
			AlwaysAvailable = true,
			SortOrder = 6,
		},
		OwnedBall = { Category = "BallAssets", DisplayName = "Owned Ball", Rarity = "Rare" },
		LockedBall = { Category = "BallAssets", DisplayName = "Locked Ball", Rarity = "Legendary" },
	},
}

T.describe("InventoryModel", function()
	T.it("projects defaults, free items, and owned items without locked items", function()
		local entries = InventoryModel.entries(CATALOG, { OwnedBall = true }, nil)
		T.expect(#entries):toEqual(5)
		T.expect(InventoryModel.find(entries, "OwnedBall") ~= nil):toBeTruthy()
		T.expect(InventoryModel.find(entries, "LockedBall")):toBeNil()
	end)

	T.it("uses explicit sort order across defaults and items", function()
		local entries = InventoryModel.entries(CATALOG, {}, "CharacterColor")
		T.expect(entries[1].displayName):toEqual("Red")
		T.expect(entries[2].displayName):toEqual("Cyan")
		T.expect(entries[3].displayName):toEqual("Purple")
	end)

	T.it("keeps configured empty categories in stable order", function()
		local categories = InventoryModel.categories(CATALOG, { "CharacterColor", "EmoteAssets", "BallAssets" })
		T.expect(categories[1]):toEqual("CharacterColor")
		T.expect(categories[2]):toEqual("EmoteAssets")
		T.expect(categories[3]):toEqual("BallAssets")
	end)

	T.it("derives selection and selected-card default restoration", function()
		local entries = InventoryModel.entries(CATALOG, { OwnedBall = true }, "BallAssets")
		local defaultEntry = InventoryModel.find(entries, "Default_BallAssets")
		local ownedEntry = InventoryModel.find(entries, "OwnedBall")
		T.expect(defaultEntry ~= nil):toBeTruthy()
		T.expect(ownedEntry ~= nil):toBeTruthy()
		T.expect(InventoryModel.isEquipped(defaultEntry, {})):toEqual(true)
		T.expect(InventoryModel.nextEquip(defaultEntry, {})):toBeNil()
		T.expect(InventoryModel.nextEquip(ownedEntry, {})):toEqual("OwnedBall")
		T.expect(InventoryModel.isEquipped(ownedEntry, { BallAssets = "OwnedBall" })):toEqual(true)
		T.expect(InventoryModel.nextEquip(ownedEntry, { BallAssets = "OwnedBall" })):toBeNil()
	end)
end)

return true
