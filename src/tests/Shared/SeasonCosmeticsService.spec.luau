--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BattlePassService = require(game:GetService("ServerScriptService").Server.Modules.BattlePassService)
local BattlePassLogic = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("BattlePassLogic")
)

local function fixture()
	local player = { UserId = -773904, Name = "SeasonCosmetics", Parent = true }
	local data = {
		Bonks = 0,
		Season = BattlePassLogic.blankState("S1"),
		Entitlements = { PremiumSeasons = {} },
		SeasonHistory = {},
	}
	local clock, grants = { now = 1500, fail = false }, {}
	local options = {
		players = { PlayerAdded = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		} },
		seasons = {
			Definitions = {
				S1 = {
					Id = "S1",
					DisplayName = "Season One",
					StartsAt = 1000,
					EndsAt = 2000,
					TierCount = 2,
					XpThresholds = { 100, 200 },
					FreeRewards = { { kind = "Bonks", amount = 50 }, { kind = "Bonks", amount = 75 } },
					PremiumRewards = { { kind = "Bonks", amount = 200 } },
					CosmeticRewards = {
						Free = { [1] = { { Key = "Launch", ItemId = "FoamLeague" } } },
						Premium = { [1] = { { Key = "Launch", ItemId = "PartyRoyal" } } },
					},
				},
			},
		},
		products = { Catalog = {} },
		playerData = {
			get = function()
				return data
			end,
		},
		rewardService = {
			grant = function(_player, reward)
				if reward.kind == "Bonks" then
					data.Bonks += reward.amount
				else
					assert(reward.duplicateRefund == false, "season backfill must not refund owned cosmetics")
					if clock.fail then
						return false, "unavailable"
					end
					grants[reward.itemId] = (grants[reward.itemId] or 0) + 1
				end
				return true
			end,
		},
		network = { handleProtected = function() end, fire = function() end },
		analyticsService = { logCustomEvent = function() end },
		time = function()
			return clock.now
		end,
		sweepSeconds = 0,
	}
	return player, data, clock, grants, options
end

return function()
	describe("Season cosmetic backfill and retry", function()
		beforeEach(BattlePassService._resetForTest)
		afterEach(BattlePassService._resetForTest)
		it("backfills a previously claimed tier without repeating its currency or duplicate compensation", function()
			local player, data, _, grants, options = fixture()
			data.Season.XP = 100
			data.Season.ClaimedFree["1"] = true
			BattlePassService.start(options)
			BattlePassService.ensureData(player)
			BattlePassService.ensureData(player)
			expect(data.Bonks).to.equal(0)
			expect(grants.FoamLeague).to.equal(1)
			expect(grants.PartyRoyal).to.equal(nil)
		end)
		it("retries a failed cosmetic after the primary reward succeeds without paying that tier again", function()
			local player, data, clock, grants, options = fixture()
			data.Season.XP = 100
			clock.fail = true
			BattlePassService.start(options)
			local state, reason = BattlePassService.claim(player, 1, "Free")
			expect(state).to.equal(nil)
			expect(reason).to.equal("grant_failed")
			expect(data.Bonks).to.equal(50)
			expect(data.Season.ClaimedFree["1"]).to.equal(true)
			clock.fail = false
			BattlePassService.ensureData(player)
			local _, retryReason = BattlePassService.claim(player, 1, "Free")
			expect(retryReason).to.equal("already_claimed")
			expect(data.Bonks).to.equal(50)
			expect(grants.FoamLeague).to.equal(1)
		end)
		it("settles archived free and late premium cosmetics against their original season once", function()
			local player, data, clock, grants, options = fixture()
			data.Season.XP = 200
			clock.now = 2500
			BattlePassService.start(options)
			BattlePassService.ensureData(player)
			expect(data.Season.Id).to.equal("")
			expect(data.SeasonHistory.S1.XP).to.equal(200)
			expect(data.Bonks).to.equal(125)
			expect(grants.FoamLeague).to.equal(1)
			expect(BattlePassService.grantPremium(player, "S1")).to.equal(true)
			expect(BattlePassService.grantPremium(player, "S1")).to.equal(true)
			expect(data.Bonks).to.equal(325)
			expect(grants.FoamLeague).to.equal(1)
			expect(grants.PartyRoyal).to.equal(1)
		end)
	end)
end
