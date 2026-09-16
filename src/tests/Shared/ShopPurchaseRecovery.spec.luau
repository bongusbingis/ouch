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
		local status, events, market, player, oldPoll, shopCalls, shopReply, openCalls, openReply, acknowledgements, productPrompts
		beforeEach(function()
			Shop.stop()
			oldPoll = Config.PurchasePollSeconds
			Config.PurchasePollSeconds = 0.02
			status = { receipts = {}, ownedPasses = {} }
			shopCalls = 0
			openCalls = 0
			productPrompts = {}
			acknowledgements = {}
			openReply = function(crateId, count, sequence)
				return {
					openId = "bonks-" .. sequence,
					source = "Bonks",
					crateId = crateId,
					count = count,
					sequence = sequence,
					results = {},
				}
			end
			shopReply = function()
				return {}
			end
			events = {}
			player = { UserId = -550123 }
			market = {
				PromptProductPurchaseFinished = signal(),
				PromptGamePassPurchaseFinished = signal(),
				PromptProductPurchase = function(_self, _player, productId)
					table.insert(productPrompts, productId)
				end,
				PromptGamePassPurchase = function() end,
			}
			Shop.start({
				DeferMarketplaceData = true,
				Player = player,
				Marketplace = market,
				Network = {
					call = function(name, ...)
						if name == "GetPurchaseState" then
							return status
						elseif name == "GetShopState" then
							shopCalls += 1
							return shopReply()
						elseif name == "OpenCrate" then
							openCalls += 1
							return openReply(...)
						end
						return {}
					end,
					fire = function()
						error("Network.fire is server-only; clients must use fireServer")
					end,
					fireServer = function(name, sequence)
						if name == "AcknowledgeBonksCrate" then
							table.insert(acknowledgements, sequence)
						end
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
			events.ShopStateChanged({ paidRandomAllowed = true, bonksOpen = { version = 1, nextSequence = 1 } })
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
		it("recovers a failed initial shop request without a manual retry", function()
			local ready = { paidRandomAllowed = true, offers = {} }
			shopReply = function()
				if shopCalls == 1 then
					error("temporarily unavailable")
				end
				return ready
			end
			expect(Shop.refresh()).to.equal(false)
			local deadline = os.clock() + 1
			repeat
				task.wait()
			until Shop.snapshot().status == "Ready" or os.clock() >= deadline
			expect(Shop.snapshot().status).to.equal("Ready")
			expect(Shop.snapshot().shopState).to.equal(ready)
			expect(shopCalls).to.equal(2)
		end)
		it("keeps a newer pushed shop state over an older request response", function()
			local newest = { paidRandomAllowed = false, offers = {} }
			shopReply = function()
				events.ShopStateChanged(newest)
				return { paidRandomAllowed = true, offers = {} }
			end
			local ok, reason = Shop.refresh()
			expect(ok).to.equal(false)
			expect(reason).to.equal("stale")
			expect(Shop.snapshot().status).to.equal("Ready")
			expect(Shop.snapshot().shopState).to.equal(newest)
		end)
		it("stops shop recovery when the client stops", function()
			shopReply = function()
				error("offline")
			end
			expect(Shop.refresh()).to.equal(false)
			Shop.stop()
			local completed = shopCalls
			task.wait(0.1)
			expect(shopCalls).to.equal(completed)
			expect(Shop.snapshot().status).to.equal("Idle")
		end)
		it("does not mistake a Bonks crate opening for an outstanding Robux purchase", function()
			local id = Products.Catalog.EffectsCrateOpen.Id
			expect(Shop.promptProduct("crate", id)).to.equal(true)
			local key = "ProductId:" .. id
			events.CrateOpened({ openId = "bonks-open", source = "Bonks", crateId = "EffectsCrate", results = {} })
			expect(Shop.snapshot().pending[key]).to.equal(true)
			events.CrateOpened({ openId = "robux-open", source = "Robux", crateId = "EffectsCrate", results = {} })
			expect(Shop.snapshot().pending[key]).to.equal(nil)
		end)
		it("prompts a named tier offer even when paid random purchases are restricted", function()
			local product = Products.Catalog.OfferUnlockCommon
			events.ShopStateChanged({
				paidRandomAllowed = false,
				paidRandomReason = "paid_random_restricted",
				offers = {
					{ itemId = "DodgeBall1", role = "RobuxCommon", rarity = "Common", purchased = false },
				},
			})
			local ok, reason = Shop.promptProduct("common", product.Id)
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
			expect(productPrompts[#productPrompts]).to.equal(product.Id)
		end)
		it("refuses exhausted and purchased tier slots before opening a prompt", function()
			local product = Products.Catalog.OfferUnlockCommon
			events.ShopStateChanged({ paidRandomAllowed = true, offers = {} })
			local missing, missingReason = Shop.promptProduct("common", product.Id)
			expect(missing).to.equal(false)
			expect(missingReason).to.equal("offer_unavailable")
			events.ShopStateChanged({
				paidRandomAllowed = true,
				offers = {
					{ itemId = "DodgeBall1", role = "RobuxCommon", rarity = "Common", purchased = true },
				},
			})
			local purchased, purchasedReason = Shop.promptProduct("common", product.Id)
			expect(purchased).to.equal(false)
			expect(purchasedReason).to.equal("offer_unavailable")
			expect(#productPrompts).to.equal(0)
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
		it("retries the same Bonks intent once after a lost response", function()
			local sequences = {}
			openReply = function(crateId, count, sequence, price)
				table.insert(sequences, sequence)
				expect(price).to.equal(500)
				if openCalls == 1 then
					error("response lost after commit")
				end
				return {
					openId = "one",
					source = "Bonks",
					crateId = crateId,
					count = count,
					sequence = sequence,
					results = {},
				}
			end
			expect(Shop.openCrate("crate", "EffectsCrate", 5, 500)).to.equal(true)
			expect(openCalls).to.equal(2)
			expect(sequences[1]).to.equal(1)
			expect(sequences[2]).to.equal(1)
			expect(Shop.snapshot().bonksRecovery).to.equal(nil)
			expect(Shop.snapshot().reveal.count).to.equal(5)
		end)
		it("accepts the Bonks reveal even when its response fails", function()
			openReply = function(crateId, count, sequence)
				events.CrateOpened({
					openId = "event-first",
					source = "Bonks",
					crateId = crateId,
					count = count,
					sequence = sequence,
					results = {},
				})
				error("response lost")
			end
			expect(Shop.openCrate("crate", "EffectsCrate", 1, 500)).to.equal(true)
			expect(openCalls).to.equal(1)
			expect(Shop.snapshot().pending["Crate:EffectsCrate"]).to.equal(nil)
		end)
		it("recovers the saved unrevealed result and acknowledges only on close", function()
			events.ShopStateChanged({
				paidRandomAllowed = false,
				bonksOpen = {
					version = 1,
					nextSequence = 8,
					unrevealed = {
						openId = "saved",
						source = "Bonks",
						crateId = "EffectsCrate",
						count = 1,
						sequence = 7,
						results = {},
					},
				},
			})
			expect(Shop.snapshot().reveal.openId).to.equal("saved")
			expect(#acknowledgements).to.equal(0)
			Shop.clearReveal()
			expect(acknowledgements[1]).to.equal(7)
			expect(Shop.snapshot().reveal).to.equal(nil)
			expect(openCalls).to.equal(0)
		end)
		it("does not send recoverable crate purchases to a legacy server", function()
			events.ShopStateChanged({ paidRandomAllowed = true })
			local ok, reason = Shop.openCrate("crate", "EffectsCrate", 1, 500)
			expect(ok).to.equal(false)
			expect(reason).to.equal("crate_recovery_unavailable")
			expect(openCalls).to.equal(0)
		end)
	end)
end
