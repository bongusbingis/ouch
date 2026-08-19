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
			return {}
		end,
	}
	local cosmeticsService = {
		grant = function(_player, itemId)
			if grantedSet[itemId] then
				return false
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
		setOwnership = function(target, passKey, isOwned)
			table.insert(ownershipWrites, { player = target, passKey = passKey, owned = isOwned })
		end,
	}
	return {
		player = player,
		purchaseFinished = purchaseFinished,
		granted = granted,
		notifications = notifications,
		ownershipWrites = ownershipWrites,
		options = {
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

		it("grants configured cosmetics for passes owned on join", function()
			local fixture = dependencies({ [91] = true })
			GamePassService.start(fixture.options)
			expect(#fixture.granted).to.equal(2)
			expect(fixture.granted[1]).to.equal("BallRed")
			expect(fixture.granted[2]).to.equal("BallBlue")
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
			GamePassService.start(fixture.options)
			-- A failed lookup must stay unknown so the boost is retried, not
			-- cached as "does not own".
			expect(#fixture.ownershipWrites).to.equal(0)
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
