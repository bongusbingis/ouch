--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")

local EntitlementService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("EntitlementService"))

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

local CATALOG = {
	Catalog = {
		TrailCollection = { EntitlementItemIds = { "TrailX" } },
		DoubleXP = { Boosts = { XpMultiplier = 2 } },
		BrawlersClub = { Boosts = { XpMultiplier = 2.5, BonksMultiplier = 1.5 } },
	},
}

local function fixture()
	local removing = signal()
	local player = { UserId = 800001, Name = "Booster", Parent = true }
	EntitlementService.start({
		players = { PlayerRemoving = removing },
		gamePasses = CATALOG,
		wait = function() end,
	})
	return player, removing
end

return function()
	describe("EntitlementService", function()
		beforeEach(function()
			EntitlementService._resetForTest()
		end)

		afterEach(function()
			EntitlementService._resetForTest()
		end)

		it("reports no multipliers before anything is known", function()
			local player = fixture()
			local multipliers = EntitlementService.multipliers(player)
			expect(multipliers.Xp).to.equal(1)
			expect(multipliers.Bonks).to.equal(1)
		end)

		it("applies the best owned booster", function()
			local player = fixture()
			EntitlementService.setOwnership(player, "DoubleXP", true)
			EntitlementService.setOwnership(player, "BrawlersClub", true)
			local multipliers = EntitlementService.multipliers(player)
			expect(multipliers.Xp).to.equal(2.5)
			expect(multipliers.Bonks).to.equal(1.5)
		end)

		it("is not ready until every boost pass has an answer", function()
			local player = fixture()
			expect(EntitlementService.isReady(player)).to.equal(false)

			EntitlementService.setOwnership(player, "DoubleXP", false)
			expect(EntitlementService.isReady(player)).to.equal(false)

			EntitlementService.setOwnership(player, "BrawlersClub", false)
			expect(EntitlementService.isReady(player)).to.equal(true)
		end)

		it("does not wait on cosmetic-only passes, which cannot change a multiplier", function()
			local player = fixture()
			EntitlementService.setOwnership(player, "DoubleXP", false)
			EntitlementService.setOwnership(player, "BrawlersClub", false)
			-- TrailCollection is still unknown, but grants no boost.
			expect(EntitlementService.isReady(player)).to.equal(true)
		end)

		it("distinguishes unowned from unknown", function()
			local player = fixture()
			expect(EntitlementService.has(player, "DoubleXP")).to.equal(false)
			EntitlementService.setOwnership(player, "DoubleXP", true)
			expect(EntitlementService.has(player, "DoubleXP")).to.equal(true)
		end)

		it("reports whether the player owns anything at all", function()
			local player = fixture()
			expect(EntitlementService.ownsAny(player)).to.equal(false)
			EntitlementService.setOwnership(player, "TrailCollection", false)
			expect(EntitlementService.ownsAny(player)).to.equal(false)
			EntitlementService.setOwnership(player, "TrailCollection", true)
			expect(EntitlementService.ownsAny(player)).to.equal(true)
		end)

		it("drops the cache when the player leaves so a refund cannot persist", function()
			local player, removing = fixture()
			EntitlementService.setOwnership(player, "BrawlersClub", true)
			expect(EntitlementService.multipliers(player).Xp).to.equal(2.5)

			removing:Fire(player)
			expect(EntitlementService.multipliers(player).Xp).to.equal(1)
			expect(EntitlementService.isReady(player)).to.equal(false)
		end)

		it("awaitReady returns immediately once every boost pass is known", function()
			local player = fixture()
			EntitlementService.setOwnership(player, "DoubleXP", true)
			EntitlementService.setOwnership(player, "BrawlersClub", false)
			expect(EntitlementService.awaitReady(player, 2)).to.equal(true)
		end)

		it("awaitReady gives up rather than blocking forever on a cold cache", function()
			local player = fixture()
			expect(EntitlementService.awaitReady(player, 0.1)).to.equal(false)
		end)
	end)
end
