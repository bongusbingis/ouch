-- Delayed authoritative receipt and entitlement projections reconcile purchase UI without another purchase.
--!nonstrict
local RS = game:GetService("ReplicatedStorage")
local Shop = require(RS.Shared.Game.Economy.ShopClient)
local Config = require(RS.Config.Economy.Shop)
local Products = require(RS.Config.Economy.Products)
local Passes = require(RS.Config.Economy.GamePasses)
local function signal()
	local callback
	return {
		Connect = function(_, fn)
			callback = fn
			return {
				Disconnect = function()
					callback = nil
				end,
			}
		end,
		fire = function(...)
			if callback then
				callback(...)
			end
		end,
	}
end
return function()
	describe("Shop purchase recovery", function()
		local status, events, market, player, oldPoll
		beforeEach(function()
			Shop.stop()
			oldPoll = Config.PurchasePollSeconds
			Config.PurchasePollSeconds = 0.02
			status = { receipts = {}, ownedPasses = {} }
			events = {}
			player = { UserId = -550123 }
			market = {
				PromptProductPurchaseFinished = signal(),
				PromptGamePassPurchaseFinished = signal(),
				PromptProductPurchase = function() end,
				PromptGamePassPurchase = function() end,
			}
			Shop.start({
				DeferMarketplaceData = true,
				Player = player,
				Marketplace = market,
				Network = {
					call = function(name)
						if name == "GetPurchaseState" then
							return status
						end
						return {}
					end,
					on = function(name, fn)
						events[name] = fn
						return {
							Disconnect = function()
								events[name] = nil
							end,
						}
					end,
				},
			})
			events.ShopStateChanged({ paidRandomAllowed = true })
		end)
		afterEach(function()
			Shop.stop()
			Config.PurchasePollSeconds = oldPoll
		end)
		local function awaitClear(key)
			local deadline = os.clock() + 1
			repeat
				task.wait()
			until not Shop.snapshot().pending[key] or os.clock() >= deadline
			expect(Shop.snapshot().pending[key]).to.equal(nil)
		end
		it("does not mistake a Bonks crate opening for an outstanding Robux purchase", function()
			local id = Products.Catalog.EffectsCrateOpen.Id
			expect(Shop.promptProduct("crate", id)).to.equal(true)
			local key = "ProductId:" .. id
			events.CrateOpened({ openId = "bonks-open", source = "Bonks", crateId = "EffectsCrate", results = {} })
			expect(Shop.snapshot().pending[key]).to.equal(true)
			events.CrateOpened({ openId = "robux-open", source = "Robux", crateId = "EffectsCrate", results = {} })
			expect(Shop.snapshot().pending[key]).to.equal(nil)
		end)
		it("recovers a saved receipt after its grant notification is lost", function()
			local id = Products.Catalog.Bonks500.Id
			status.receipts = { { id = "old", at = 1, productId = id, payload = { kind = "Bonks", amount = 500 } } }
			expect(Shop.promptProduct("bonks", id)).to.equal(true)
			table.insert(
				status.receipts,
				{ id = "new", at = 2, productId = id, payload = { kind = "Bonks", amount = 500 } }
			)
			awaitClear("ProductId:" .. id)
			expect(Shop.snapshot().grant.grantId).to.equal("new")
			expect(Shop.snapshot().grant.amount).to.equal(500)
		end)
		it("recovers a fully granted pass after its notification is lost", function()
			local id = Passes.Catalog.Showtime.Id
			expect(Shop.promptGamePass("pass", id)).to.equal(true)
			status.ownedPasses.Showtime = true
			awaitClear("GamePassId:" .. id)
			expect(Shop.snapshot().ownedPasses.Showtime).to.equal(true)
			expect(Shop.snapshot().grant.passId).to.equal(id)
		end)
	end)
end
