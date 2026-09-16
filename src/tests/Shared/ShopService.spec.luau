--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopService = require(game:GetService("ServerScriptService").Server.Modules.ShopService)
local Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local FeaturedRotation = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Economy")
		:WaitForChild("FeaturedRotation")
)
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local ShopRotation = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("ShopRotation")
)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("GamePasses"))

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
		it("migrates the old flat schema once without reshuffling after a purchase", function()
			local offers = ShopService.offersFor(player)
			expect(#offers).to.equal(#Shop.Rotation.Roles)
			expect(data.Shop.Version).to.equal(1)
			expect(type(data.Shop.Offers[1])).to.equal("table")
			local stored = data.Shop.Offers
			for _, id in CosmeticsLogic.grantIds(Cosmetics.Items, offers[1]) do
				data.Cosmetics.Owned[id] = true
			end
			local after = ShopService.offersFor(player)
			expect(data.Shop.Offers).to.equal(stored)
			for index, itemId in offers do
				expect(after[index]).to.equal(itemId)
			end
			expect(ShopService.stateFor(player).offers[1].owned).to.equal(true)
		end)
		it("filters retired stored offers without replacing the surviving offers", function()
			ShopService.ensure(player)
			data.Shop.Offers = {
				{ ItemId = "FoamLeagueHead", Role = "RobuxCommon", Rarity = Cosmetics.Items.FoamLeagueHead.Rarity },
				{ ItemId = "FoamLeague", Role = "Bonks", Rarity = Cosmetics.Items.FoamLeague.Rarity },
				{ ItemId = "RainHopper", Role = "RobuxCommon", Rarity = Cosmetics.Items.RainHopper.Rarity },
			}
			local offers = ShopService.offersFor(player)
			expect(#offers).to.equal(2)
			expect(offers[1]).to.equal("FoamLeague")
			expect(offers[2]).to.equal("RainHopper")
			expect(#data.Shop.Offers).to.equal(3)
			expect(ShopService.isPurchasable(player, "FoamLeagueHead")).to.equal(false)
		end)
		it("resolves each tier only against its named slot and records a purchase", function()
			local records = ShopService.offerRecords(player)
			local common, premium
			for _, record in records do
				if record.Role == "RobuxCommon" then
					common = record
				elseif record.Role == "RobuxPremium" then
					premium = record
				end
			end
			local itemId, role = ShopService.resolveOfferForTier(player, "Common")
			expect(itemId).to.equal(common.ItemId)
			expect(role).to.equal("RobuxCommon")
			local wrongTier = if premium.Rarity == "Rare" then "Legendary" else "Rare"
			local missing, mismatchRole, mismatch = ShopService.resolveOfferForTier(player, wrongTier)
			expect(missing).to.equal(nil)
			expect(mismatchRole).to.equal("RobuxPremium")
			expect(mismatch).to.equal("rarity_mismatch")
			expect(ShopService.markPurchased(player, role)).to.equal(true)
			local again, _, reason = ShopService.resolveOfferForTier(player, "Common")
			expect(again).to.equal(nil)
			expect(reason).to.equal("already_purchased")
			local state = ShopService.stateFor(player)
			for _, offer in state.offers do
				if offer.role == "RobuxCommon" then
					expect(offer.purchased).to.equal(true)
					expect(offer.bonksPrice).to.equal(nil)
				elseif offer.role == "Bonks" then
					expect(offer.bonksPrice).to.be.ok()
				end
			end
		end)
		it("substitutes through resolution when the shown item becomes owned", function()
			local common
			for _, record in ShopService.offerRecords(player) do
				if record.Role == "RobuxCommon" then
					common = record
				end
			end
			for _, itemId in CosmeticsLogic.grantIds(Cosmetics.Items, common.ItemId) do
				data.Cosmetics.Owned[itemId] = true
			end
			local itemId, role, reason = ShopService.resolveOfferForTier(player, "Common")
			expect(itemId).to.equal(nil)
			expect(role).to.equal("RobuxCommon")
			expect(reason).to.equal("already_owned")
		end)
		it("omits the Common slot when every eligible Common is owned", function()
			for itemId, item in Cosmetics.Items do
				if item.Rarity == "Common" then
					local eligible = ShopRotation.isEligible(item, Shop.Rotation.Categories)
					if eligible then
						for _, grantId in CosmeticsLogic.grantIds(Cosmetics.Items, itemId) do
							data.Cosmetics.Owned[grantId] = true
						end
					end
				end
			end
			data.Shop.Version = nil
			local records = ShopService.offerRecords(player)
			expect(#records).to.equal(2)
			for _, record in records do
				expect(record.Role == "RobuxCommon").to.equal(false)
			end
			local itemId, role, reason = ShopService.resolveOfferForTier(player, "Common")
			expect(itemId).to.equal(nil)
			expect(role).to.equal("RobuxCommon")
			expect(reason).to.equal("slot_missing")
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

	describe("Starter offer eligibility", function()
		local NOW = 2_000_000_000
		local PASS_KEY = GamePasses.StarterOffer.PassKey
		local player, data, entitlements

		beforeEach(function()
			ShopService._resetForTest()
			player = { UserId = 991144 }
			data = {
				Cosmetics = { Owned = {} },
				Shop = { Bucket = FeaturedRotation.periodIndex(Shop.Rotation.RotationSeconds, NOW), Offers = {} },
				Onboarding = { FirstJoinAt = NOW - 3600 },
				Receipts = {},
			}
			entitlements = {
				ready = true,
				owned = {},
				isReady = function()
					return entitlements.ready
				end,
				has = function(_, key)
					return entitlements.owned[key] == true
				end,
				ownsAny = function()
					return next(entitlements.owned) ~= nil
				end,
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
						return true, nil
					end,
				},
				entitlements = entitlements,
				time = function()
					return NOW
				end,
				sweepSeconds = 0,
			})
		end)
		afterEach(ShopService._resetForTest)

		it("offers the starter window to a stamped new player who has bought nothing", function()
			local offer = ShopService.stateFor(player).starterOffer
			expect(offer).to.be.ok()
			expect(offer.passKey).to.equal(PASS_KEY)
			expect(offer.expiresAt).to.equal(NOW - 3600 + GamePasses.StarterOffer.WindowSeconds)
		end)

		it("withholds the offer until pass ownership is known", function()
			entitlements.ready = false
			expect(ShopService.stateFor(player).starterOffer).to.equal(nil)
		end)

		it("withholds the offer once the player owns any pass or holds any receipt", function()
			entitlements.owned = { DoubleXP = true }
			expect(ShopService.stateFor(player).starterOffer).to.equal(nil)
			entitlements.owned = {}
			data.Receipts = { ["12345"] = NOW - 10 }
			expect(ShopService.stateFor(player).starterOffer).to.equal(nil)
		end)

		it("withholds the offer from an unstamped profile and after the window closes", function()
			data.Onboarding.FirstJoinAt = 0
			expect(ShopService.stateFor(player).starterOffer).to.equal(nil)
			data.Onboarding.FirstJoinAt = NOW - GamePasses.StarterOffer.WindowSeconds
			expect(ShopService.stateFor(player).starterOffer).to.equal(nil)
		end)
	end)
end
