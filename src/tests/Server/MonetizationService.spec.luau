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

		it("grants Cash receipts once and emits one authoritative grant event", function()
			local player = { UserId = 720001 }
			local data = { Cash = 0, Receipts = {} }
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
							Type = "Cash",
							CashAmount = 500,
						},
					},
				},
				crates = {},
				playerData = {
					get = function(target)
						return if target == player then data else nil
					end,
					addCash = function(target, amount)
						if target == player then
							data.Cash += amount
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
			expect(data.Cash).to.equal(500)
			expect(data.Receipts["purchase-1"]).to.equal(12345)
			expect(#grants).to.equal(1)
			expect(grants[1].name).to.equal("StorePurchaseGranted")
			expect(grants[1].payload.amount).to.equal(500)
			expect(#economyEvents).to.equal(1)

			expect(marketplace.ProcessReceipt(receipt)).to.equal(Enum.ProductPurchaseDecision.PurchaseGranted)
			expect(data.Cash).to.equal(500)
			expect(#grants).to.equal(1)
			expect(#economyEvents).to.equal(1)
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
	end)
end
