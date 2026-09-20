--!strict

local T = require(script.Parent.TestKit)
local SeasonCosmetics = require(script.Parent.Parent.Game.Progression.SeasonCosmetics)
local BattlePassLogic = require(script.Parent.Parent.Game.Progression.BattlePassLogic)

local function fixture()
	return {
		TierCount = 2,
		CosmeticRewards = {
			Free = { [1] = { { Key = "launch", ItemId = "Hat" } } },
			Premium = { [2] = { { Key = "launch", ItemId = "Crown" } } },
		},
	},
		BattlePassLogic.blankState("S1")
end

T.describe("Supplemental season cosmetics", function()
	T.it("backfills claimed tiers without claiming currency or granting unearned tracks", function()
		local season, state = fixture()
		T.expect(#SeasonCosmetics.pending(season, state, true)):toEqual(0)
		state.ClaimedFree["1"] = true
		state.ClaimedPremium["2"] = true
		local free = SeasonCosmetics.pending(season, state, false)
		T.expect(#free):toEqual(1)
		T.expect(free[1].itemId):toEqual("Hat")
		T.expect(#SeasonCosmetics.pending(season, state, true)):toEqual(2)
	end)

	T.it("retries only unfinished grants and preserves them through archive normalization", function()
		local season, state = fixture()
		state.ClaimedFree["1"] = true
		state.ClaimedPremium["2"] = true
		local owed = SeasonCosmetics.pending(season, state, true)
		state.CosmeticClaims[owed[1].key] = true
		local archived = BattlePassLogic.readState(state)
		local retry = SeasonCosmetics.pending(season, archived, true)
		T.expect(#retry):toEqual(1)
		T.expect(retry[1].itemId):toEqual("Crown")
		T.expect(SeasonCosmetics.public(season, archived, 1, "Free")[1].claimed):toBeTruthy()
	end)

	T.it("treats replacement content as a new grant without invalidating the earlier claim", function()
		local season, state = fixture()
		state.ClaimedFree["1"] = true
		local original = SeasonCosmetics.pending(season, state, false)[1]
		state.CosmeticClaims[original.key] = true
		T.expect(#SeasonCosmetics.pending(season, state, false)):toEqual(0)
		season.CosmeticRewards.Free[1][1].ItemId = "NewHat"
		local replacement = SeasonCosmetics.pending(season, state, false)
		T.expect(#replacement):toEqual(1)
		T.expect(replacement[1].itemId):toEqual("NewHat")
		T.expect(state.CosmeticClaims[original.key]):toBeTruthy()
		T.expect(state.ClaimedFree["1"]):toBeTruthy()
	end)

	T.it("treats only absent historical cosmetic claims as empty", function()
		local season, state = fixture()
		state.ClaimedFree["1"] = true
		state.CosmeticClaims = nil :: any
		T.expect(#SeasonCosmetics.pending(season, state, false)):toEqual(1)
		T.expect(SeasonCosmetics.public(season, state, 1, "Free")[1].claimed):toBeFalsy()
		state.CosmeticClaims = false :: any
		local ok = pcall(SeasonCosmetics.pending, season, state, false)
		T.expect(ok):toBeFalsy()
	end)
end)

return true
