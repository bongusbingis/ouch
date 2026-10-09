--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = Shared:WaitForChild("Game"):WaitForChild("Economy")
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Logic = require(Economy:WaitForChild("CosmeticsLogic"))
local Inventory = require(Economy:WaitForChild("InventoryModel"))
local DirectPurchase = require(Economy:WaitForChild("DirectPurchase"))
local Rotation = require(Economy:WaitForChild("ShopRotation"))
local Modules = game:GetService("ServerScriptService").Server.Modules
local PlayerData = require(Modules.PlayerData)
local CosmeticsService = require(Modules.CosmeticsService)
local FakePlayer = require(script.Parent.Parent.Helpers.FakePlayer)

return function()
	describe("Atomic costume grants", function()
		local player, data
		beforeEach(function()
			player = FakePlayer.new(-773901)
			data = { Cosmetics = { Owned = { FoamLeagueHead = true }, Equipped = {} } }
			PlayerData._profiles[player.UserId] = { Data = data }
		end)
		afterEach(function()
			PlayerData._profiles[player.UserId] = nil
		end)
		it("finishes partial ownership without persisting a second outfit flag", function()
			expect(CosmeticsService.grant(player, "FoamLeague")).to.equal(true)
			expect(data.Cosmetics.Owned.FoamLeague).to.equal(nil)
			expect(data.Cosmetics.Owned.FoamLeagueBody).to.equal(true)
			expect(data.Cosmetics.Owned.FoamLeagueFeet).to.equal(true)
			local granted, reason = CosmeticsService.grant(player, "FoamLeague")
			expect(granted).to.equal(false)
			expect(reason).to.equal("already_owned")
			expect(CosmeticsService.equip(player, "CostumeAssets", "FoamLeague")).to.equal(true)
			expect(player:GetAttribute("Equip_CostumeAssets")).to.equal("FoamLeague")
			expect(CosmeticsService.revokeForAdmin(player, "FoamLeagueHead")).to.equal(true)
			expect(player:GetAttribute("Equip_CostumeAssets")).to.equal("")
		end)
	end)

	describe("Composed costume ownership", function()
		it("derives ownership only from the complete set of atomic components", function()
			local owned = { FoamLeague = true, FoamLeagueHead = true }
			expect(Logic.isOwned(Cosmetics.Items, owned, "FoamLeague")).to.equal(false)
			owned.FoamLeagueBody, owned.FoamLeagueFeet = true, true
			expect(Logic.isOwned(Cosmetics.Items, owned, "FoamLeague")).to.equal(true)
			owned.FoamLeague = nil
			expect(Logic.isOwned(Cosmetics.Items, owned, "FoamLeague")).to.equal(true)
		end)

		it("expands immutable grants without modifying catalog composition", function()
			local ids = Logic.grantIds(Cosmetics.Items, "FoamLeague")
			expect(#ids).to.equal(3)
			expect(ids[1]).to.equal("FoamLeagueHead")
			ids[1] = "changed"
			expect(Cosmetics.Items.FoamLeague.Contents[1]).to.equal("FoamLeagueHead")
			expect(Logic.grantIds(Cosmetics.Items, "missing")).to.equal(nil)
		end)

		it("exposes and equips complete looks while retaining hidden component ownership", function()
			local owned = { FoamLeagueHead = true, FoamLeagueBody = true, FoamLeagueFeet = true }
			local entries = Inventory.entries(Cosmetics, owned, "CostumeAssets")
			expect(#entries).to.equal(2)
			expect(Inventory.find(entries, "FoamLeague") ~= nil).to.equal(true)
			expect(Inventory.find(entries, "FoamLeagueHead")).to.equal(nil)
			expect(Logic.canEquip(Cosmetics.Items, Cosmetics.Slots, owned, "CostumeAssets", "FoamLeague")).to.equal(
				true
			)
			local accepted, reason =
				Logic.canEquip(Cosmetics.Items, Cosmetics.Slots, owned, "CostumeAssets", "FoamLeagueHead")
			expect(accepted).to.equal(false)
			expect(reason).to.equal("not_equippable")
			local price, purchaseReason =
				DirectPurchase.evaluate("FoamLeague", Cosmetics.Items, Cosmetics.Rarities, owned, 10000)
			expect(price).to.equal(nil)
			expect(purchaseReason).to.equal("already_owned")
			expect(DirectPurchase.priceFor("FoamLeagueHead", Cosmetics.Items, Cosmetics.Rarities)).to.equal(nil)
		end)

		it("keeps completed sets out of rotation and partial sets available", function()
			local owned = { FoamLeagueHead = true, FoamLeagueBody = true, FoamLeagueFeet = true, RainHopperHead = true }
			local pool = Rotation.pool(Cosmetics.Items, { "CostumeAssets" })
			expect(#pool).to.equal(4)
			local offers = Rotation.draw(1, 1, pool, owned, 8, Cosmetics.Items)
			expect(table.find(offers, "FoamLeague")).to.equal(nil)
			expect(table.find(offers, "RainHopper") ~= nil).to.equal(true)
			expect(Rotation.isEligible({ Category = "Other", Rarity = "Common", ShopEligible = true }, {})).to.equal(
				true
			)
			expect(Rotation.isEligible({ Category = "Other", Rarity = "Common", ShopEligible = false }, { "Other" })).to.equal(
				false
			)
		end)

		it("rejects missing, nested, cyclic and duplicate-role compositions", function()
			local base = {
				Look = { Category = "CostumeAssets", Contents = { "Head", "Body", "Feet" } },
				Head = { Category = "CostumeAssets", CostumePiece = "Head" },
				Body = { Category = "CostumeAssets", CostumePiece = "Body" },
				Feet = { Category = "CostumeAssets", CostumePiece = "Feet" },
			}
			expect(pcall(Logic.validate, base)).to.equal(true)
			for _, contents in { { "Head", "Body", "Missing" }, { "Head", "Body", "Look" }, { "Head", "Body", "Head" } } do
				local invalid = table.clone(base)
				invalid.Look = { Category = "CostumeAssets", Contents = contents }
				expect(pcall(Logic.validate, invalid)).to.equal(false)
			end
			local invalid = table.clone(base)
			invalid.Head = { Category = "CostumeAssets", CostumePiece = "Head", Contents = { "Head", "Body", "Feet" } }
			expect(pcall(Logic.validate, invalid)).to.equal(false)
		end)
	end)
end
