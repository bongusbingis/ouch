--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")

local BattlePassService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("BattlePassService"))

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

local SEASONS = {
	Definitions = {
		S1 = {
			Id = "S1",
			DisplayName = "Season One",
			StartsAt = 1000,
			EndsAt = 2000,
			TierCount = 3,
			XpThresholds = { 100, 250, 500 },
			FreeRewards = { [1] = { kind = "Bonks", amount = 50 }, [2] = { kind = "Bonks", amount = 75 } },
			PremiumRewards = { [1] = { kind = "Bonks", amount = 200 } },
		},
		S2 = {
			Id = "S2",
			DisplayName = "Season Two",
			StartsAt = 3000,
			EndsAt = 4000,
			TierCount = 2,
			XpThresholds = { 100, 200 },
			FreeRewards = { [1] = { kind = "Bonks", amount = 60 } },
			PremiumRewards = {},
		},
	},
}

local function fixture(now)
	local clock = { value = now }
	local player = { UserId = 900001, Name = "PassPlayer", Parent = true }
	local profile = {
		Bonks = 0,
		Season = nil,
		Entitlements = nil,
	}
	local granted = {}
	local fired = {}
	local options = {
		players = {
			PlayerAdded = signal(),
			GetPlayers = function()
				return { player }
			end,
		},
		seasons = SEASONS,
		products = { Catalog = { SeasonPassS1 = { Type = "SeasonPass", SeasonId = "S1", Id = 5150 } } },
		playerData = {
			get = function()
				return profile
			end,
		},
		rewardService = {
			grant = function(_player, reward)
				table.insert(granted, reward)
				return true, nil
			end,
		},
		network = {
			fire = function(name, target, payload)
				table.insert(fired, { name = name, target = target, payload = payload })
			end,
			handleProtected = function() end,
		},
		analyticsService = { logCustomEvent = function() end },
		time = function()
			return clock.value
		end,
		runAsync = function(callback)
			callback()
		end,
		sweepSeconds = 0,
	}
	return { player = player, profile = profile, granted = granted, fired = fired, clock = clock, options = options }
end

return function()
	describe("BattlePassService", function()
		beforeEach(function()
			BattlePassService._resetForTest()
		end)

		afterEach(function()
			BattlePassService._resetForTest()
		end)

		it("adopts the active season and starts at tier zero", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			local state = BattlePassService.stateFor(f.player)
			expect(state.active).to.equal(true)
			expect(state.seasonId).to.equal("S1")
			expect(state.tier).to.equal(0)
			expect(state.premiumProductId).to.equal(5150)
		end)

		it("accrues season XP and derives tier from it", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.addSeasonXp(f.player, 260)
			local state = BattlePassService.stateFor(f.player)
			expect(state.xp).to.equal(260)
			expect(state.tier).to.equal(2)
		end)

		it("refuses premium tiers until the product is granted", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.addSeasonXp(f.player, 500)

			local _, reason = BattlePassService.claim(f.player, 1, "Premium")
			expect(reason).to.equal("premium_required")

			expect(BattlePassService.grantPremium(f.player, "S1")).to.equal(true)
			local state = BattlePassService.claim(f.player, 1, "Premium")
			expect(state).to.be.ok()
			expect(f.granted[#f.granted].amount).to.equal(200)
		end)

		it("marks a tier claimed only once", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.addSeasonXp(f.player, 500)

			BattlePassService.claim(f.player, 1, "Free")
			local _, reason = BattlePassService.claim(f.player, 1, "Free")
			expect(reason).to.equal("already_claimed")
			expect(#f.granted).to.equal(1)
		end)

		it("refuses tiers the player has not reached", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			local _, reason = BattlePassService.claim(f.player, 2, "Free")
			expect(reason).to.equal("tier_locked")
		end)

		it("grants premium idempotently so a receipt retry resolves", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			expect(BattlePassService.grantPremium(f.player, "S1")).to.equal(true)
			expect(BattlePassService.grantPremium(f.player, "S1")).to.equal(true)
		end)

		it("refuses premium for a season that does not exist", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			expect(BattlePassService.grantPremium(f.player, "S99")).to.equal(false)
			expect(BattlePassService.grantPremium(f.player, nil)).to.equal(false)
		end)

		it("settles unclaimed tiers before resetting at rollover", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.addSeasonXp(f.player, 500)
			expect(#f.granted).to.equal(0)

			-- Cross into season two without ever opening the pass.
			f.clock.value = 3500
			local state = BattlePassService.stateFor(f.player)

			-- Both free tiers were owed and are paid out, not lost.
			expect(#f.granted).to.equal(2)
			expect(state.seasonId).to.equal("S2")
			expect(state.xp).to.equal(0)
			expect(state.tier).to.equal(0)
		end)

		it("keeps premium entitlements across a rollover", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.grantPremium(f.player, "S1")

			f.clock.value = 3500
			BattlePassService.stateFor(f.player)
			expect(f.profile.Entitlements.PremiumSeasons.S1).to.equal(true)
		end)

		it("reports an inactive pass during the gap between seasons", function()
			local f = fixture(2500)
			BattlePassService.start(f.options)
			local state = BattlePassService.stateFor(f.player)
			expect(state.active).to.equal(false)

			-- XP earned with no season live must not silently vanish into S1.
			BattlePassService.addSeasonXp(f.player, 100)
			expect(BattlePassService.stateFor(f.player).active).to.equal(false)
		end)

		it("claims everything owed in one call", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.grantPremium(f.player, "S1")
			BattlePassService.addSeasonXp(f.player, 500)

			local _, _, claimed = BattlePassService.claimAll(f.player)
			expect(claimed).to.equal(3)
			expect(#f.granted).to.equal(3)

			local _, _, again = BattlePassService.claimAll(f.player)
			expect(again).to.equal(0)
		end)

		it("does not mark a tier claimed when the grant fails", function()
			local f = fixture(1500)
			f.options.rewardService.grant = function()
				return false, "grant_failed"
			end
			BattlePassService.start(f.options)
			BattlePassService.addSeasonXp(f.player, 500)

			local _, reason = BattlePassService.claim(f.player, 1, "Free")
			expect(reason).to.equal("grant_failed")

			-- Still claimable once the underlying grant works again.
			f.options.rewardService.grant = function()
				return true, nil
			end
			expect(BattlePassService.claim(f.player, 1, "Free")).to.be.ok()
		end)
	end)
end
