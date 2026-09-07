--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Server.Modules
local PlayerData = require(Modules.PlayerData)
local MonetizationService = require(Modules.MonetizationService)
local Bundles = require(ReplicatedStorage.Config.Economy.Bundles)
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local FakePlayer = require(script.Parent.Parent.Helpers.FakePlayer)

return function()
	describe("Configured complete outfit bundle fulfillment", function()
		local player, data
		beforeEach(function()
			MonetizationService._resetForTest()
			player = FakePlayer.new(-773903)
			data = {
				Bonks = 0,
				Receipts = {},
				Cosmetics = { Owned = { FoamLeagueHead = true, DodgeBall3 = true }, Equipped = {} },
			}
			PlayerData._profiles[player.UserId] = { Data = data }
		end)
		afterEach(function()
			PlayerData._profiles[player.UserId] = nil
			MonetizationService._resetForTest()
		end)
		it("grants the authored launch contents and applies one duplicate refund across receipt retries", function()
			local marketplace, events = {}, {}
			MonetizationService.start({
				marketplace = marketplace,
				players = {
					GetPlayerByUserId = function()
						return player
					end,
				},
				products = { ById = { [206] = { Type = "Bundle", BundleId = "StarterOutfitBundle" } } },
				bundles = Bundles,
				playerData = {
					get = PlayerData.get,
					acquireWriteLease = function()
						return function() end
					end,
					confirmReceiptSaved = function()
						return true
					end,
				},
				analyticsService = { logEconomyEvent = function() end },
				network = {
					fire = function(_name, _player, payload)
						table.insert(events, payload)
					end,
				},
			})
			local receipt = { PlayerId = player.UserId, ProductId = 206, PurchaseId = "launch-outfit" }
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			for _, id in Cosmetics.Items.FoamLeague.Contents do
				expect(data.Cosmetics.Owned[id]).to.equal(true)
			end
			expect(data.Cosmetics.Owned.FoamLeague).to.equal(nil)
			expect(data.Cosmetics.Owned.StarPop).to.equal(true)
			expect(data.Bonks).to.equal(Cosmetics.Rarities.Common.DupeBonks)
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			expect(data.Bonks).to.equal(Cosmetics.Rarities.Common.DupeBonks)
			expect(#events).to.equal(1)
			expect(events[1].bundleId).to.equal("StarterOutfitBundle")
		end)
	end)
end
