--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopService = require(game:GetService("ServerScriptService").Server.Modules.ShopService)
local Shop = require(ReplicatedStorage.Config.Economy.Shop)
local FeaturedRotation = require(ReplicatedStorage.Shared.Game.Economy.FeaturedRotation)
local CosmeticsLogic = require(ReplicatedStorage.Shared.Game.Economy.CosmeticsLogic)
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)

return function()
	describe("Shop migration and policy projection", function()
		local player, data, allowed, reason
		beforeEach(function()
			ShopService._resetForTest()
			player = { UserId = 728193 }
			allowed, reason = true, nil
			data = {
				Cosmetics = { Owned = {} },
				Shop = { Bucket = FeaturedRotation.periodIndex(Shop.Rotation.RotationSeconds, 100000), Offers = {} },
			}
			ShopService.start({
				playerData = {
					get = function()
						return data
					end,
				},
				network = { handleProtected = function() end },
				paidRandomPolicy = {
					canReceivePaidRandom = function()
						return allowed, reason
					end,
				},
				time = function()
					return 100000
				end,
				sweepSeconds = 0,
			})
		end)
		afterEach(ShopService._resetForTest)
		it("fills the previously empty same-period rotation without reshuffling after a purchase", function()
			local offers = ShopService.offersFor(player)
			expect(#offers).to.equal(Shop.Rotation.OfferCount)
			for _, id in CosmeticsLogic.grantIds(Cosmetics.Items, offers[1]) do
				data.Cosmetics.Owned[id] = true
			end
			local after = ShopService.offersFor(player)
			for index, itemId in offers do
				expect(after[index]).to.equal(itemId)
			end
			expect(ShopService.stateFor(player).offers[1].owned).to.equal(true)
		end)
		it("filters retired stored offers without replacing the surviving offers", function()
			data.Shop.Offers = { "FoamLeagueHead", "FoamLeague", "RainHopper" }
			local offers = ShopService.offersFor(player)
			expect(#offers).to.equal(2)
			expect(offers[1]).to.equal("FoamLeague")
			expect(offers[2]).to.equal("RainHopper")
			expect(#data.Shop.Offers).to.equal(3)
			expect(ShopService.isPurchasable(player, "FoamLeagueHead")).to.equal(false)
		end)
		it("projects policy restrictions and lookup failures without removing direct offers", function()
			allowed, reason = false, "paid_random_restricted"
			local restricted = ShopService.stateFor(player)
			expect(restricted.paidRandomAllowed).to.equal(false)
			expect(restricted.paidRandomReason).to.equal(reason)
			expect(#restricted.offers > 0).to.equal(true)
			reason = "policy_lookup_failed"
			expect(ShopService.stateFor(player).paidRandomReason).to.equal(reason)
			allowed, reason = true, nil
			expect(ShopService.stateFor(player).paidRandomAllowed).to.equal(true)
		end)
	end)
end
