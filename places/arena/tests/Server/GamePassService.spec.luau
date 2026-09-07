-- Name: GamePassService.spec.luau
-- Author: Jack C.
-- Description: In-place spec for game pass reconciliation: idempotent cosmetic grants on join and after purchase, ownership caching including negative results, and rejection of passes naming unknown cosmetics.
-- Created: 2026-08-08

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")

local GamePassService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("GamePassService"))

local function signal()
	local callbacks = {}
	local object = {}
	function object:Connect(callback)
		local connection = { connected = true }
		function connection:Disconnect()
			self.connected = false
		end
		table.insert(callbacks, { callback = callback, connection = connection })
		return connection
	end
	function object:Fire(...)
		for _, entry in callbacks do
			if entry.connection.connected then
				entry.callback(...)
			end
		end
	end
	return object
end

local function dependencies(owned)
	local player = { UserId = 700001, Name = "PassOwner", Parent = true }
	local playerAdded = signal()
	local purchaseFinished = signal()
	local granted = {}
	local notifications = {}
	local grantEvents = {}
	local grantedSet = {}
	local marketplace = {
		PromptGamePassPurchaseFinished = purchaseFinished,
		UserOwnsGamePassAsync = function(_self, _userId, passId)
			return owned[passId] == true
		end,
	}
	local players = {
		PlayerAdded = playerAdded,
		GetPlayers = function()
			return { player }
		end,
	}
	local playerData = {
		get = function()
			return { Cosmetics = { Owned = grantedSet } }
		end,
	}
	local cosmeticsService = {
		grant = function(_player, itemId)
			if grantedSet[itemId] then
				return false, "already_owned"
			end
			grantedSet[itemId] = true
			table.insert(granted, itemId)
			return true
		end,
	}
	local gamePasses = {
		Catalog = {
			StarterPass = {
				Enabled = true,
				Categories = { "BallAssets" },
				EntitlementItemIds = { "BallRed", "BallBlue" },
			},
		},
		ById = {
			[91] = {
				Enabled = true,
				EntitlementItemIds = { "BallRed", "BallBlue" },
			},
		},
		KeyById = { [91] = "StarterPass" },
	}
	local ownershipWrites = {}
	local entitlementService = {
		has = function(_player, key)
			for index = #ownershipWrites, 1, -1 do
				if ownershipWrites[index].passKey == key then
					return ownershipWrites[index].owned
				end
			end
			return false
		end,
		setOwnership = function(target, passKey, isOwned)
			table.insert(ownershipWrites, { player = target, passKey = passKey, owned = isOwned })
		end,
	}
	return {
		player = player,
		purchaseFinished = purchaseFinished,
		granted = granted,
		notifications = notifications,
		grantEvents = grantEvents,
		ownershipWrites = ownershipWrites,
		options = {
			analyticsService = {
				logCustomEvent = function(_player, name, _value, fields)
					table.insert(grantEvents, { name = name, fields = fields })
				end,
			},
			entitlementService = entitlementService,
			marketplace = marketplace,
			players = players,
			playerData = playerData,
			cosmeticsService = cosmeticsService,
			network = {
				fire = function(name, target, payload)
					table.insert(notifications, { name = name, target = target, payload = payload })
				end,
			},
			gamePasses = gamePasses,
			cosmetics = { Items = { BallRed = { Category = "BallAssets" }, BallBlue = { Category = "BallAssets" } } },
			runAsync = function(callback)
				callback()
			end,
			wait = function() end,
		},
	}
end

return function()
	describe("GamePassService", function()
		beforeEach(function()
			GamePassService._resetForTest()
		end)

		afterEach(function()
			GamePassService._resetForTest()
		end)

		it("acknowledges a pass only after all configured items are granted", function()
			local deps = dependencies({ [91] = true })
			local held = deps.options.cosmeticsService.grant
			deps.options.cosmeticsService.grant = function(player, id)
				if id == "BallBlue" then
					return false, "temporary"
				end
				return held(player, id)
			end
			local checkedPartial = false
			deps.options.wait = function()
				expect(GamePassService.purchaseState(deps.player).StarterPass).to.equal(nil)
				checkedPartial = true
				deps.options.cosmeticsService.grant = held
			end
			GamePassService.start(deps.options)
			expect(checkedPartial).to.equal(true)
			expect(GamePassService.purchaseState(deps.player).StarterPass).to.equal(true)
		end)

		it("grants configured cosmetics for passes owned on join", function()
			local fixture = dependencies({ [91] = true })
			GamePassService.start(fixture.options)
			expect(#fixture.granted).to.equal(2)
			expect(fixture.granted[1]).to.equal("BallRed")
			expect(fixture.granted[2]).to.equal("BallBlue")
		end)

		it("reconciles a profile that loads after the former thirty-second deadline", function()
			local fixture = dependencies({ [91] = true })
			local elapsed = 0
			fixture.options.playerData.get = function()
				return if elapsed >= 45 then {} else nil
			end
			fixture.options.wait = function(seconds)
				elapsed += seconds
			end
			GamePassService.start(fixture.options)
			expect(elapsed >= 45).to.equal(true)
			expect(#fixture.granted).to.equal(2)
			expect(fixture.ownershipWrites[1].owned).to.equal(true)
		end)

		it("cancels an unresolved profile when its player leaves", function()
			local fixture = dependencies({ [91] = true })
			fixture.options.playerData.get = function()
				return nil
			end
			fixture.options.wait = function()
				fixture.player.Parent = nil
			end
			GamePassService.start(fixture.options)
			expect(#fixture.granted).to.equal(0)
			expect(#fixture.ownershipWrites).to.equal(0)
		end)

		it("continues reconciling a hidden pass that already has a platform identity", function()
			local fixture = dependencies({ [91] = true })
			local definition = fixture.options.gamePasses.Catalog.StarterPass
			definition.CatalogStatus = "Hidden"
			definition.Id = 91
			fixture.options.gamePasses.ById[91] = definition
			GamePassService.start(fixture.options)
			expect(#fixture.granted).to.equal(2)
			expect(fixture.ownershipWrites[1].owned).to.equal(true)
		end)

		it("fulfills the actual Showtime collection and recovers a partial grant", function()
			local config = game:GetService("ReplicatedStorage").Config
			local definition = require(config.Economy.GamePasses).Catalog.Showtime
			local owned = { [definition.Id] = false }
			local fixture = dependencies(owned)
			fixture.options.gamePasses = {
				Catalog = { Showtime = definition },
				ById = { [definition.Id] = definition },
				KeyById = { [definition.Id] = "Showtime" },
			}
			fixture.options.cosmetics = require(config.Cosmetics.Cosmetics)
			local grant = fixture.options.cosmeticsService.grant
			local failed = false
			fixture.options.cosmeticsService.grant = function(player, itemId)
				if itemId == "ShowtimeFlex" and not failed then
					failed = true
					return false, "no_profile"
				end
				return grant(player, itemId)
			end
			GamePassService.start(fixture.options)
			expect(#fixture.granted).to.equal(0)
			owned[definition.Id] = true
			fixture.purchaseFinished:Fire(fixture.player, definition.Id, true)
			fixture.purchaseFinished:Fire(fixture.player, definition.Id, true)
			expect(#fixture.granted).to.equal(3)
			expect(table.find(fixture.granted, "ShowtimeTwirl") ~= nil).to.equal(true)
			expect(table.find(fixture.granted, "ShowtimeFlex") ~= nil).to.equal(true)
			expect(table.find(fixture.granted, "ShowtimeBounce") ~= nil).to.equal(true)
			expect(#fixture.notifications).to.equal(1)
			expect(#fixture.grantEvents).to.equal(3)
			for _, event in fixture.grantEvents do
				expect(event.name).to.equal("CosmeticGranted")
				expect(event.fields.passId).to.equal(definition.Id)
			end
		end)

		it("rechecks a completed purchase and keeps repeated grants idempotent", function()
			local owned = { [91] = false }
			local fixture = dependencies(owned)
			GamePassService.start(fixture.options)
			expect(#fixture.granted).to.equal(0)

			owned[91] = true
			fixture.purchaseFinished:Fire(fixture.player, 91, true)
			fixture.purchaseFinished:Fire(fixture.player, 91, true)
			expect(#fixture.granted).to.equal(2)
			expect(fixture.granted[1]).to.equal("BallRed")
			expect(fixture.granted[2]).to.equal("BallBlue")
			expect(#fixture.notifications).to.equal(1)
			expect(fixture.notifications[1].name).to.equal("StorePurchaseGranted")
		end)

		it("records ownership for the entitlement cache, including not-owned", function()
			local fixture = dependencies({ [91] = false })
			GamePassService.start(fixture.options)
			expect(#fixture.ownershipWrites).to.equal(1)
			expect(fixture.ownershipWrites[1].passKey).to.equal("StarterPass")
			expect(fixture.ownershipWrites[1].owned).to.equal(false)
		end)

		it("records ownership again after a completed purchase", function()
			local owned = { [91] = false }
			local fixture = dependencies(owned)
			GamePassService.start(fixture.options)

			owned[91] = true
			fixture.purchaseFinished:Fire(fixture.player, 91, true)
			local last = fixture.ownershipWrites[#fixture.ownershipWrites]
			expect(last.passKey).to.equal("StarterPass")
			expect(last.owned).to.equal(true)
		end)

		it("never caches ownership when the platform lookup fails", function()
			local fixture = dependencies({})
			fixture.options.marketplace.UserOwnsGamePassAsync = function()
				error("network down")
			end
			fixture.options.wait = function()
				fixture.player.Parent = nil
			end
			GamePassService.start(fixture.options)
			expect(#fixture.ownershipWrites).to.equal(0)
		end)

		it("retries unresolved ownership while the player remains connected", function()
			local fixture = dependencies({ [91] = true })
			local lookup = fixture.options.marketplace.UserOwnsGamePassAsync
			local attempts = 0
			fixture.options.marketplace.UserOwnsGamePassAsync = function(...)
				attempts += 1
				if attempts == 1 then
					error("temporary failure")
				end
				return lookup(...)
			end
			GamePassService.start(fixture.options)
			expect(attempts).to.equal(2)
			expect(#fixture.ownershipWrites).to.equal(1)
			expect(#fixture.granted).to.equal(2)
		end)

		it("retries a partial entitlement grant without duplicating completed items", function()
			local f = dependencies({ [91] = true })
			local grant = f.options.cosmeticsService.grant
			local failed = false
			f.options.cosmeticsService.grant = function(player, itemId)
				if itemId == "BallBlue" and not failed then
					failed = true
					return false, "no_profile"
				end
				return grant(player, itemId)
			end
			GamePassService.start(f.options)
			expect(#f.granted).to.equal(2)
		end)

		it("keeps retrying a purchased pass beyond a short platform outage", function()
			local owned = { [91] = false }
			local f = dependencies(owned)
			GamePassService.start(f.options)
			local attempts = 0
			f.options.marketplace.UserOwnsGamePassAsync = function()
				attempts += 1
				return attempts > 5
			end
			f.purchaseFinished:Fire(f.player, 91, true)
			expect(attempts).to.equal(6)
			expect(#f.granted).to.equal(2)
			expect(#f.notifications).to.equal(1)
		end)

		it("rejects enabled passes that reference unknown cosmetics", function()
			local fixture = dependencies({})
			fixture.options.cosmetics = { Items = {} }
			expect(function()
				GamePassService.start(fixture.options)
			end).to.throw()
		end)
	end)
end
