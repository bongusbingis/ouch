-- Description: In-place spec for the battle pass service: season adoption, XP accrual and tier derivation, premium gating and idempotent grants, claim rules, and season rollover settlement.

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

local function pendingAward(f, seasonId, xp)
	f.profile.MatchAwards = {
		Version = 1,
		Pending = {
			award = {
				Ready = true,
				ProgressionApplied = true,
				SeasonApplied = true,
				SeasonId = seasonId,
				Awarded = { XP = xp },
			},
		},
		Completed = {},
	}
	return f.profile.MatchAwards.Pending.award
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

			f.clock.value = 3500
			local state = BattlePassService.stateFor(f.player)

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

		it("settles a delayed premium receipt against archived progress exactly once", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.addSeasonXp(f.player, 500)
			f.clock.value = 3500
			BattlePassService.stateFor(f.player)
			expect(f.profile.SeasonHistory.S1.XP).to.equal(500)
			expect(#f.granted).to.equal(2)
			expect(BattlePassService.grantPremium(f.player, "S1")).to.equal(true)
			expect(#f.granted).to.equal(3)
			expect(BattlePassService.grantPremium(f.player, "S1")).to.equal(true)
			expect(#f.granted).to.equal(3)
			expect(f.profile.Season.XP).to.equal(0)
		end)

		it("retains failed rollover grants and retries only unpaid tiers", function()
			local f = fixture(1500)
			local fail = true
			f.options.rewardService.grant = function(_player, reward)
				if reward.amount == 75 and fail then
					return false, "unavailable"
				end
				table.insert(f.granted, reward)
				return true
			end
			BattlePassService.start(f.options)
			BattlePassService.addSeasonXp(f.player, 500)
			f.clock.value = 3500
			BattlePassService.stateFor(f.player)
			expect(#f.granted).to.equal(1)
			expect(f.profile.SeasonHistory.S1.ClaimedFree["2"]).to.equal(nil)
			fail = false
			BattlePassService.stateFor(f.player)
			BattlePassService.stateFor(f.player)
			expect(#f.granted).to.equal(2)
		end)

		it("credits delayed match XP to its original season", function()
			local f = fixture(3500)
			BattlePassService.start(f.options)
			expect(BattlePassService.addSeasonXp(f.player, 250, "S1")).to.equal(true)
			expect(f.profile.SeasonHistory.S1.XP).to.equal(250)
			expect(f.profile.Season.XP).to.equal(0)
		end)

		it("settles an applied zero-XP award without inventing an archive", function()
			local f = fixture(3500)
			pendingAward(f, "S1", 0)
			BattlePassService.start(f.options)
			local settled, reason = BattlePassService.settleArchivedSeason(f.player, "S1", "award")
			expect(settled).to.equal(true)
			expect(reason).to.equal(nil)
			expect(f.profile.SeasonHistory.S1).to.equal(nil)
			expect(#f.granted).to.equal(0)
		end)

		it("rejects positive XP and invalid journal preconditions when an archive is absent", function()
			local cases = {
				{
					"positive XP",
					function(record)
						record.Awarded.XP = 1
					end,
					"Awarded.XP",
				},
				{ "wrong award ID", function() end, "record required" },
				{ "empty award ID", function() end, "nonempty award ID" },
				{ "unknown season", function() end, "known nonempty season ID" },
				{
					"missing journal",
					function(_record, f)
						f.profile.MatchAwards = nil
					end,
					"V1 Pending journal",
				},
				{
					"wrong journal version",
					function(_record, f)
						f.profile.MatchAwards.Version = 2
					end,
					"V1 Pending journal",
				},
				{
					"missing pending",
					function(_record, f)
						f.profile.MatchAwards.Pending = nil
					end,
					"V1 Pending journal",
				},
				{
					"unready",
					function(record)
						record.Ready = false
					end,
					"ready, progression-applied",
				},
				{
					"unapplied progression",
					function(record)
						record.ProgressionApplied = false
					end,
					"ready, progression-applied",
				},
				{
					"unapplied season",
					function(record)
						record.SeasonApplied = false
					end,
					"ready, progression-applied",
				},
				{
					"wrong season",
					function(record)
						record.SeasonId = "S2"
					end,
					".SeasonId",
				},
				{
					"nonnumeric zero",
					function(record)
						record.Awarded.XP = "0"
					end,
					".Awarded.XP",
				},
				{
					"nonfinite zero",
					function(record)
						record.Awarded.XP = 0 / 0
					end,
					".Awarded.XP",
				},
				{
					"missing awarded",
					function(record)
						record.Awarded = nil
					end,
					".Awarded.XP",
				},
			}
			for _, case in cases do
				BattlePassService._resetForTest()
				local f = fixture(3500)
				local record = pendingAward(f, "S1", 0)
				case[2](record, f)
				BattlePassService.start(f.options)
				local awardId = if case[1] == "wrong award ID"
					then "other"
					else if case[1] == "empty award ID" then "" else "award"
				local seasonId = if case[1] == "unknown season" then "Retired" else "S1"
				local settled, reason = BattlePassService.settleArchivedSeason(f.player, seasonId, awardId)
				expect(settled).to.equal(false)
				expect(string.find(reason, `SeasonHistory.{seasonId}`, 1, true)).to.be.ok()
				expect(string.find(reason, case[3], 1, true)).to.be.ok()
				expect(f.profile.SeasonHistory.S1).to.equal(nil)
				expect(#f.granted).to.equal(0)
			end
		end)

		it("settles an existing archive's owed tiers even for a zero-XP award", function()
			local f = fixture(3500)
			pendingAward(f, "S1", 0)
			f.profile.SeasonHistory = {
				S1 = { Id = "S1", XP = 500, ClaimedFree = {}, ClaimedPremium = {}, CosmeticClaims = {} },
			}
			local fail = true
			f.options.rewardService.grant = function(_player, reward)
				if reward.amount == 75 and fail then
					return false, "reward unavailable"
				end
				table.insert(f.granted, reward)
				return true
			end
			BattlePassService.start(f.options)
			local settled, reason = BattlePassService.settleArchivedSeason(f.player, "S1", "award")
			expect(settled).to.equal(false)
			expect(string.find(reason, "tier 2 Free Bonks 75", 1, true)).to.be.ok()
			expect(f.profile.MatchAwards.Pending.award).to.be.ok()
			fail = false
			expect(BattlePassService.settleArchivedSeason(f.player, "S1", "award")).to.equal(true)
			expect(#f.granted).to.equal(2)
		end)

		it("keeps an archived award pending after a partial tier grant failure", function()
			local f = fixture(3500)
			f.profile.SeasonHistory = {
				S1 = { Id = "S1", XP = 500, ClaimedFree = {}, ClaimedPremium = {}, CosmeticClaims = {} },
			}
			local fail = true
			f.options.rewardService.grant = function(_player, reward)
				if reward.amount == 75 and fail then
					return false, "reward unavailable"
				end
				table.insert(f.granted, reward)
				return true
			end
			BattlePassService.start(f.options)
			local settled, reason = BattlePassService.settleArchivedSeason(f.player, "S1", "award-17")
			expect(settled).to.equal(false)
			expect(string.find(reason, "award-17", 1, true)).to.be.ok()
			expect(string.find(reason, "tier 2 Free Bonks 75", 1, true)).to.be.ok()
			expect(f.profile.SeasonHistory.S1.ClaimedFree["1"]).to.equal(true)
			expect(f.profile.SeasonHistory.S1.ClaimedFree["2"]).to.equal(nil)
			fail = false
			expect(BattlePassService.settleArchivedSeason(f.player, "S1", "award-17")).to.equal(true)
			expect(#f.granted).to.equal(2)
		end)

		it("reports a thrown archived grant with its tier and retries it", function()
			local f = fixture(3500)
			f.profile.SeasonHistory = {
				S1 = { Id = "S1", XP = 500, ClaimedFree = {}, ClaimedPremium = {}, CosmeticClaims = {} },
			}
			local fail = true
			f.options.rewardService.grant = function(_player, reward)
				if reward.amount == 75 and fail then
					error("inventory offline")
				end
				table.insert(f.granted, reward)
				return true
			end
			BattlePassService.start(f.options)
			local settled, reason = BattlePassService.settleArchivedSeason(f.player, "S1", "award-18")
			expect(settled).to.equal(false)
			expect(string.find(reason, "award-18", 1, true)).to.be.ok()
			expect(string.find(reason, "tier 2 Free Bonks 75", 1, true)).to.be.ok()
			expect(string.find(reason, "inventory offline", 1, true)).to.be.ok()
			fail = false
			expect(BattlePassService.settleArchivedSeason(f.player, "S1", "award-18")).to.equal(true)
			expect(#f.granted).to.equal(2)
		end)

		it("rejects malformed archived claim state before granting a tier", function()
			local f = fixture(3500)
			f.profile.SeasonHistory = {
				S1 = { Id = "S1", XP = 500, ClaimedPremium = {}, CosmeticClaims = {} },
			}
			BattlePassService.start(f.options)
			local ok, reason = pcall(BattlePassService.settleArchivedSeason, f.player, "S1", "award-19")
			expect(ok).to.equal(false)
			expect(string.find(tostring(reason), "SeasonHistory.S1.ClaimedFree", 1, true)).to.be.ok()
			expect(#f.granted).to.equal(0)
		end)

		it("rejects an archive key and stored Id mismatch before any tier grant", function()
			local f = fixture(3500)
			f.profile.SeasonHistory = {
				S1 = { Id = "", XP = 500, ClaimedFree = {}, ClaimedPremium = {}, CosmeticClaims = {} },
			}
			BattlePassService.start(f.options)
			local ok, reason = pcall(BattlePassService.settleArchivedSeason, f.player, "S1", "award-20")
			expect(ok).to.equal(false)
			expect(string.find(tostring(reason), "SeasonHistory.S1.Id", 1, true)).to.be.ok()
			expect(#f.granted).to.equal(0)
		end)

		it("keeps malformed active state intact instead of rolling it over", function()
			local f = fixture(1500)
			BattlePassService.start(f.options)
			BattlePassService.stateFor(f.player)
			f.profile.Season.XP = 0 / 0
			f.clock.value = 3500
			local ok, reason = pcall(BattlePassService.stateFor, f.player)
			expect(ok).to.equal(false)
			expect(string.find(tostring(reason), "Season.XP", 1, true)).to.be.ok()
			expect(f.profile.Season.Id).to.equal("S1")
			expect(f.profile.SeasonHistory.S1).to.equal(nil)
			expect(#f.granted).to.equal(0)
		end)

		it("upgrades an old archived missing CosmeticClaims field after validation", function()
			local f = fixture(3500)
			f.profile.SeasonHistory = {
				S1 = { Id = "S1", XP = 100, ClaimedFree = { [1] = true, ["2"] = false }, ClaimedPremium = {} },
			}
			BattlePassService.start(f.options)
			expect(BattlePassService.settleArchivedSeason(f.player, "S1", "award-21")).to.equal(true)
			expect(type(f.profile.SeasonHistory.S1.CosmeticClaims)).to.equal("table")
			expect(#f.granted).to.equal(0)
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

			f.options.rewardService.grant = function()
				return true, nil
			end
			expect(BattlePassService.claim(f.player, 1, "Free")).to.be.ok()
		end)
	end)
end
