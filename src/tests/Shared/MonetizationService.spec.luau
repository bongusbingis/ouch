-- Name: MonetizationService.spec.luau
-- Author: Jack C.
-- Description: In-place spec that receipts grant exactly once and emit one authoritative grant event, and that unknown products are left for Roblox to retry.
-- Created: 2026-08-11

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")

local MonetizationService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MonetizationService"))

return function()
	describe("MonetizationService", function()
		beforeEach(function()
			MonetizationService._resetForTest()
		end)

		afterEach(function()
			MonetizationService._resetForTest()
		end)

		it("grants Bonks receipts once and emits one authoritative grant event", function()
			local player = { UserId = 720001 }
			local data = { Bonks = 0, Receipts = {} }
			local marketplace = {}
			local grants = {}
			local economyEvents = {}
			MonetizationService.start({
				marketplace = marketplace,
				players = {
					GetPlayerByUserId = function(_self, userId)
						return if userId == player.UserId then player else nil
					end,
				},
				products = {
					ById = {
						[202] = {
							Type = "Bonks",
							BonksAmount = 500,
						},
					},
				},
				crates = {},
				playerData = {
					acquireWriteLease = function()
						return function() end
					end,
					confirmReceiptSaved = function(_target, key)
						return data.Receipts[key] ~= nil
					end,
					get = function(target)
						return if target == player then data else nil
					end,
					addBonks = function(target, amount)
						if target == player then
							data.Bonks += amount
						end
					end,
				},
				analyticsService = {
					logEconomyEvent = function(...)
						table.insert(economyEvents, { ... })
					end,
				},
				network = {
					fire = function(name, target, payload)
						table.insert(grants, { name = name, target = target, payload = payload })
					end,
				},
				time = function()
					return 12345
				end,
			})

			local receipt = {
				PlayerId = player.UserId,
				ProductId = 202,
				PurchaseId = "purchase-1",
				CurrencySpent = 49,
			}
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			expect(data.Bonks).to.equal(500)
			expect(data.Receipts["purchase-1"]).to.equal(12345)
			expect(#grants).to.equal(1)
			expect(grants[1].name).to.equal("StorePurchaseGranted")
			expect(grants[1].payload.amount).to.equal(500)
			expect(#economyEvents).to.equal(1)

			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			expect(data.Bonks).to.equal(500)
			expect(#grants).to.equal(1)
			expect(#economyEvents).to.equal(1)
		end)

		it("serializes concurrent receipts and resumes a partial bundle without duplicate refunds", function()
			local player = { UserId = 720003 }
			local data = { Bonks = 0, Receipts = {} }
			local marketplace = {}
			local calls = {}
			local fail = true
			local first = true
			local receipt = { PlayerId = player.UserId, ProductId = 203, PurchaseId = "bundle-one" }
			MonetizationService.start({
				marketplace = marketplace,
				players = {
					GetPlayerByUserId = function()
						return player
					end,
				},
				products = { ById = { [203] = { Type = "Bundle", BundleId = "bundle" } } },
				bundles = { Catalog = { bundle = { ItemIds = { "one", "two" } } } },
				playerData = {
					get = function()
						return data
					end,
					acquireWriteLease = function()
						return function() end
					end,
					confirmReceiptSaved = function()
						return true
					end,
				},
				rewardService = {
					grant = function(_player, reward)
						if first then
							first = false
							expect(marketplace.ProcessReceipt(receipt)).to.equal(
								Enum.ProductPurchaseDecision.NotProcessedYet
							)
						end
						if reward.itemId == "two" and fail then
							return false
						end
						calls[reward.itemId] = (calls[reward.itemId] or 0) + 1
						return true
					end,
				},
				analyticsService = {
					logEconomyEvent = function()
						error("analytics unavailable")
					end,
				},
				network = { fire = function() end },
			})
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
			fail = false
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			expect(calls.one).to.equal(1)
			expect(calls.two).to.equal(1)
			expect(data.ReceiptWork["bundle-one"]).to.equal(nil)
		end)

		it("leaves unknown products for Roblox to retry", function()
			local marketplace = {}
			MonetizationService.start({
				marketplace = marketplace,
				players = { GetPlayerByUserId = function() end },
				products = { ById = {} },
				crates = {},
			})
			local decision = marketplace.ProcessReceipt({
				PlayerId = 1,
				ProductId = 999,
				PurchaseId = "unknown",
			})
			expect(decision).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
		end)

		it("does not acknowledge an unsaved receipt or grant it again on retry", function()
			local player = { UserId = 720002 }
			local data = { Bonks = 0, Receipts = {} }
			local durable = false
			local marketplace = {}
			local leases = 0
			MonetizationService.start({
				marketplace = marketplace,
				players = {
					GetPlayerByUserId = function()
						return player
					end,
				},
				products = { ById = { [202] = { Type = "Bonks", BonksAmount = 500 } } },
				crates = {},
				playerData = {
					get = function()
						return data
					end,
					addBonks = function(_player, amount)
						data.Bonks += amount
					end,
					acquireWriteLease = function()
						leases += 1
						return function()
							leases -= 1
						end
					end,
					confirmReceiptSaved = function()
						return durable
					end,
				},
				analyticsService = { logEconomyEvent = function() end },
				network = { fire = function() end },
			})
			local receipt = { PlayerId = player.UserId, ProductId = 202, PurchaseId = "unsaved" }
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
			expect(data.Bonks).to.equal(500)
			expect(leases).to.equal(0)
			durable = true
			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			expect(data.Bonks).to.equal(500)
			expect(leases).to.equal(0)
		end)
	end)
end
