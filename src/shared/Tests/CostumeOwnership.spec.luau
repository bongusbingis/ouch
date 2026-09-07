--!strict

local T = require(script.Parent.TestKit)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)
local Logic = require(script.Parent.Parent.Game.Economy.CosmeticsLogic)
local Inventory = require(script.Parent.Parent.Game.Economy.InventoryModel)
local DirectPurchase = require(script.Parent.Parent.Game.Economy.DirectPurchase)
local Rotation = require(script.Parent.Parent.Game.Economy.ShopRotation)

T.describe("Composed costume ownership", function()
	T.it("derives ownership only from the complete set of atomic components", function()
		local owned = { FoamLeague = true, FoamLeagueHead = true }
		T.expect(Logic.isOwned(Cosmetics.Items, owned, "FoamLeague")):toEqual(false)
		owned.FoamLeagueBody, owned.FoamLeagueFeet = true, true
		T.expect(Logic.isOwned(Cosmetics.Items, owned, "FoamLeague")):toEqual(true)
		owned.FoamLeague = nil
		T.expect(Logic.isOwned(Cosmetics.Items, owned, "FoamLeague")):toEqual(true)
	end)

	T.it("expands immutable grants without modifying catalog composition", function()
		local ids = Logic.grantIds(Cosmetics.Items, "FoamLeague")
		T.expect(#ids):toEqual(3)
		T.expect(ids[1]):toEqual("FoamLeagueHead")
		ids[1] = "changed"
		T.expect(Cosmetics.Items.FoamLeague.Contents[1]):toEqual("FoamLeagueHead")
		T.expect(Logic.grantIds(Cosmetics.Items, "missing")):toBeNil()
	end)

	T.it("exposes and equips complete looks while retaining hidden component ownership", function()
		local owned = { FoamLeagueHead = true, FoamLeagueBody = true, FoamLeagueFeet = true }
		local entries = Inventory.entries(Cosmetics, owned, "CostumeAssets")
		T.expect(#entries):toEqual(2)
		T.expect(Inventory.find(entries, "FoamLeague") ~= nil):toEqual(true)
		T.expect(Inventory.find(entries, "FoamLeagueHead")):toBeNil()
		T.expect(Logic.canEquip(Cosmetics.Items, Cosmetics.Slots, owned, "CostumeAssets", "FoamLeague")):toEqual(true)
		local accepted, reason =
			Logic.canEquip(Cosmetics.Items, Cosmetics.Slots, owned, "CostumeAssets", "FoamLeagueHead")
		T.expect(accepted):toEqual(false)
		T.expect(reason):toEqual("not_equippable")
		local price, purchaseReason =
			DirectPurchase.evaluate("FoamLeague", Cosmetics.Items, Cosmetics.Rarities, owned, 10000)
		T.expect(price):toBeNil()
		T.expect(purchaseReason):toEqual("already_owned")
		T.expect(DirectPurchase.priceFor("FoamLeagueHead", Cosmetics.Items, Cosmetics.Rarities)):toBeNil()
	end)

	T.it("keeps completed sets out of rotation and partial sets available", function()
		local owned = { FoamLeagueHead = true, FoamLeagueBody = true, FoamLeagueFeet = true, RainHopperHead = true }
		local pool = Rotation.pool(Cosmetics.Items, { "CostumeAssets" })
		T.expect(#pool):toEqual(4)
		local offers = Rotation.draw(1, 1, pool, owned, 8, Cosmetics.Items)
		T.expect(table.find(offers, "FoamLeague")):toBeNil()
		T.expect(table.find(offers, "RainHopper") ~= nil):toEqual(true)
		T.expect(Rotation.isEligible({ Category = "Other", Rarity = "Common", ShopEligible = true }, {})):toEqual(true)
		T.expect(Rotation.isEligible({ Category = "Other", Rarity = "Common", ShopEligible = false }, { "Other" }))
			:toEqual(false)
	end)

	T.it("rejects missing, nested, cyclic and duplicate-role compositions", function()
		local base = {
			Look = { Category = "CostumeAssets", Contents = { "Head", "Body", "Feet" } },
			Head = { Category = "CostumeAssets", CostumePiece = "Head" },
			Body = { Category = "CostumeAssets", CostumePiece = "Body" },
			Feet = { Category = "CostumeAssets", CostumePiece = "Feet" },
		}
		T.expect(pcall(Logic.validate, base)):toEqual(true)
		for _, contents in { { "Head", "Body", "Missing" }, { "Head", "Body", "Look" }, { "Head", "Body", "Head" } } do
			local invalid = table.clone(base)
			invalid.Look = { Category = "CostumeAssets", Contents = contents }
			T.expect(pcall(Logic.validate, invalid)):toEqual(false)
		end
		local invalid = table.clone(base)
		invalid.Head = { Category = "CostumeAssets", CostumePiece = "Head", Contents = { "Head", "Body", "Feet" } }
		T.expect(pcall(Logic.validate, invalid)):toEqual(false)
	end)
end)

return true
