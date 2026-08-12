--!strict

local T = require(script.Parent.TestKit)
local BattlePassLogic = require(script.Parent.Parent.Game.Progression.BattlePassLogic)
local Seasons = require(script.Parent.Parent.Parent.Config.Seasons)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)

local SEASON = {
	Id = "T1",
	DisplayName = "Test Season",
	StartsAt = 1000,
	EndsAt = 2000,
	TierCount = 3,
	XpThresholds = { 100, 250, 500 },
	FreeRewards = {
		[1] = { kind = "Cash", amount = 50 },
		[3] = { kind = "Cosmetic", itemId = "TrailX" },
	},
	PremiumRewards = {
		[2] = { kind = "Cash", amount = 200 },
		[3] = { kind = "Cash", amount = 400 },
	},
}

local function stateAt(xp: number)
	local state = BattlePassLogic.blankState("T1")
	state.XP = xp
	return state
end

T.describe("BattlePassLogic", function()
	T.it("derives tier from XP at and around each threshold", function()
		T.expect(BattlePassLogic.tierForXp(SEASON, 0)):toEqual(0)
		T.expect(BattlePassLogic.tierForXp(SEASON, 99)):toEqual(0)
		T.expect(BattlePassLogic.tierForXp(SEASON, 100)):toEqual(1)
		T.expect(BattlePassLogic.tierForXp(SEASON, 249)):toEqual(1)
		T.expect(BattlePassLogic.tierForXp(SEASON, 250)):toEqual(2)
		T.expect(BattlePassLogic.tierForXp(SEASON, 500)):toEqual(3)
	end)

	T.it("clamps tier at the cap while XP keeps accumulating", function()
		T.expect(BattlePassLogic.tierForXp(SEASON, 999999)):toEqual(3)
	end)

	T.it("reports progress into the next tier", function()
		local tier, into, needed = BattlePassLogic.tierProgress(SEASON, 175)
		T.expect(tier):toEqual(1)
		T.expect(into):toEqual(75)
		T.expect(needed):toEqual(150)

		local capped, cappedInto, cappedNeeded = BattlePassLogic.tierProgress(SEASON, 900)
		T.expect(capped):toEqual(3)
		T.expect(cappedInto):toEqual(0)
		T.expect(cappedNeeded):toEqual(0)
	end)

	T.it("selects the active season only inside its window", function()
		local defs = { T1 = SEASON }
		T.expect(BattlePassLogic.activeSeason(defs, 999)):toBeNil()
		T.expect(BattlePassLogic.activeSeason(defs, 1000).Id):toEqual("T1")
		T.expect(BattlePassLogic.activeSeason(defs, 1999).Id):toEqual("T1")
		-- EndsAt is exclusive, so the rest gap starts immediately.
		T.expect(BattlePassLogic.activeSeason(defs, 2000)):toBeNil()
	end)

	T.it("ignores archived seasons when picking the active one", function()
		local archived = table.clone(SEASON)
		archived.Archived = true
		T.expect(BattlePassLogic.activeSeason({ T1 = archived }, 1500)):toBeNil()
	end)

	T.it("gates claims on tier, ownership, duplication, and reward existence", function()
		local locked = BattlePassLogic.canClaim(SEASON, stateAt(0), 1, "Free", false)
		T.expect(locked):toEqual(false)

		local ok = BattlePassLogic.canClaim(SEASON, stateAt(100), 1, "Free", false)
		T.expect(ok):toEqual(true)

		local _, premium = BattlePassLogic.canClaim(SEASON, stateAt(500), 2, "Premium", false)
		T.expect(premium):toEqual("premium_required")

		local _, noReward = BattlePassLogic.canClaim(SEASON, stateAt(500), 2, "Free", false)
		T.expect(noReward):toEqual("no_reward")

		local _, unknown = BattlePassLogic.canClaim(SEASON, stateAt(500), 9, "Free", true)
		T.expect(unknown):toEqual("unknown_tier")

		local _, lockedReason = BattlePassLogic.canClaim(SEASON, stateAt(0), 3, "Free", true)
		T.expect(lockedReason):toEqual("tier_locked")

		local claimed = stateAt(500)
		claimed.ClaimedFree["1"] = true
		local _, already = BattlePassLogic.canClaim(SEASON, claimed, 1, "Free", true)
		T.expect(already):toEqual("already_claimed")
	end)

	T.it("lists everything owed, in tier order, respecting premium ownership", function()
		local free = BattlePassLogic.unclaimedTiers(SEASON, stateAt(500), false)
		T.expect(#free):toEqual(2)
		T.expect(free[1].tier):toEqual(1)
		T.expect(free[1].track):toEqual("Free")
		T.expect(free[2].tier):toEqual(3)

		local withPremium = BattlePassLogic.unclaimedTiers(SEASON, stateAt(500), true)
		T.expect(#withPremium):toEqual(4)
		T.expect(withPremium[1].tier):toEqual(1)
		T.expect(withPremium[2].tier):toEqual(2)
		T.expect(withPremium[2].track):toEqual("Premium")
	end)

	T.it("omits already-claimed tiers from what is owed", function()
		local state = stateAt(500)
		state.ClaimedFree["1"] = true
		state.ClaimedPremium["2"] = true
		local owed = BattlePassLogic.unclaimedTiers(SEASON, state, true)
		T.expect(#owed):toEqual(2)
		T.expect(owed[1].tier):toEqual(3)
	end)

	T.it("owes nothing at zero XP", function()
		T.expect(#BattlePassLogic.unclaimedTiers(SEASON, stateAt(0), true)):toEqual(0)
	end)

	T.it("normalises stored state and tolerates numeric claim keys", function()
		local state = BattlePassLogic.readState({
			Id = "T1",
			XP = 300,
			ClaimedFree = { [1] = true, [2] = false },
			ClaimedPremium = { ["2"] = true },
		})
		T.expect(state.XP):toEqual(300)
		T.expect(state.ClaimedFree["1"]):toEqual(true)
		T.expect(state.ClaimedFree["2"]):toBeNil()
		T.expect(state.ClaimedPremium["2"]):toEqual(true)
	end)

	T.it("returns a blank state for missing or malformed storage", function()
		T.expect(BattlePassLogic.readState(nil).XP):toEqual(0)
		T.expect(BattlePassLogic.readState("nope").Id):toEqual("")
	end)

	T.it("builds a client payload covering every tier", function()
		local payload = BattlePassLogic.publicState(SEASON, stateAt(250), true, 4242)
		T.expect(payload.active):toEqual(true)
		T.expect(payload.tier):toEqual(2)
		T.expect(#payload.tiers):toEqual(3)
		T.expect(payload.tiers[1].unlocked):toEqual(true)
		T.expect(payload.tiers[3].unlocked):toEqual(false)
		T.expect(payload.premiumProductId):toEqual(4242)
		T.expect(payload.tiers[2].premiumReward.amount):toEqual(200)
	end)

	T.it("reports an inactive payload during the rest gap", function()
		local payload = BattlePassLogic.publicState(nil, BattlePassLogic.blankState(""), false, nil)
		T.expect(payload.active):toEqual(false)
		T.expect(#payload.tiers):toEqual(0)
	end)

	T.it("ships a season whose full track is reachable in a sane number of hours", function()
		local season = Seasons.Definitions.S1
		local total = season.XpThresholds[season.TierCount]
		-- ~1,650 XP/hour from ProgressionXP at roughly ten matches an hour.
		local hours = total / 1650
		T.expect(hours > 5):toBeTruthy()
		T.expect(hours < 20):toBeTruthy()
	end)

	T.it("gives the shipped free track real rewards, not just a premium teaser", function()
		local season = Seasons.Definitions.S1
		local freeCount = 0
		local freeCosmetics = 0
		for _, reward in season.FreeRewards do
			freeCount += 1
			if reward.kind == "Cosmetic" then
				freeCosmetics += 1
			end
		end
		T.expect(freeCount >= 6):toBeTruthy()
		T.expect(freeCosmetics >= 3):toBeTruthy()
	end)

	T.it("rewards only cosmetics that exist and never grants XP back into itself", function()
		for _, season in Seasons.Definitions do
			for _, track in { season.FreeRewards, season.PremiumRewards } do
				for _, reward in track do
					T.expect(reward.kind ~= "XP"):toBeTruthy()
					if reward.kind == "Cosmetic" then
						T.expect(Cosmetics.Items[reward.itemId] ~= nil):toBeTruthy()
					end
				end
			end
		end
	end)
end)

return true
