--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Server.Modules
local PlayerData = require(Modules.PlayerData)
local ShopService = require(Modules.ShopService)
local DirectPurchaseService = require(Modules.DirectPurchaseService)
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local Shop = require(ReplicatedStorage.Config.Economy.Shop)
local FeaturedRotation = require(ReplicatedStorage.Shared.Game.Economy.FeaturedRotation)
local FakePlayer = require(script.Parent.Parent.Helpers.FakePlayer)

return function()
	describe("Complete outfit direct purchases", function()
		local player, data
		beforeEach(function()
			ShopService._resetForTest()
			player = FakePlayer.new(-773902)
			data = {
				Bonks = 10000,
				Cosmetics = { Owned = { FoamLeagueHead = true }, Equipped = {} },
				Shop = {
					Bucket = FeaturedRotation.periodIndex(Shop.Rotation.RotationSeconds, 100000),
					Offers = { "FoamLeague", "RainHopper" },
				},
			}
			PlayerData._profiles[player.UserId] = { Data = data }
			ShopService.start({
				network = { handleProtected = function() end },
				time = function()
					return 100000
				end,
				sweepSeconds = 0,
			})
		end)
		afterEach(function()
			PlayerData._profiles[player.UserId] = nil
			ShopService._resetForTest()
		end)
		it("charges once for an offered outfit, completes a partial set, and keeps the other offer stable", function()
			local purchased = DirectPurchaseService.purchase(player, "FoamLeague")
			expect(purchased.itemId).to.equal("FoamLeague")
			expect(data.Bonks).to.equal(10000 - Cosmetics.Rarities.Common.DirectBonks)
			expect(data.Cosmetics.Owned.FoamLeague).to.equal(nil)
			for _, id in Cosmetics.Items.FoamLeague.Contents do
				expect(data.Cosmetics.Owned[id]).to.equal(true)
			end
			local balance = data.Bonks
			local duplicate, reason = DirectPurchaseService.purchase(player, "FoamLeague")
			expect(duplicate).to.equal(nil)
			expect(reason).to.equal("already_owned")
			expect(data.Bonks).to.equal(balance)
			expect(ShopService.offersFor(player)[2]).to.equal("RainHopper")
		end)
		it("refuses unoffered, component and unaffordable purchases without changing the profile", function()
			for _, id in { "SnackStack", "FoamLeagueHead", "SundaeSprinter" } do
				local result, reason = DirectPurchaseService.purchase(player, id)
				expect(result).to.equal(nil)
				expect(reason).to.equal("not_offered")
			end
			data.Bonks = 0
			local result, reason = DirectPurchaseService.purchase(player, "FoamLeague")
			expect(result).to.equal(nil)
			expect(reason).to.equal("insufficient_bonks")
			expect(data.Cosmetics.Owned.FoamLeagueBody).to.equal(nil)
			expect(data.Cosmetics.Owned.FoamLeagueFeet).to.equal(nil)
			expect(data.Bonks).to.equal(0)
		end)
	end)
end
