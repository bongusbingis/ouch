-- Description: Spec for the developer gate shared by lobby solo play and the arena match skip: only sufficiently ranked group members pass, and an unreadable rank is a refusal rather than an error.

--!strict

local T = require(script.Parent.TestKit)
local DevSoloPlay = require(script.Parent.Parent.Game.Matchmaking.DevSoloPlay)

local function rankPlayer(rank: number)
	return {
		GetRankInGroup = function(_self, groupId: number)
			T.expect(groupId):toEqual(291738800)
			return rank
		end,
	}
end

local function brokenPlayer()
	return {
		GetRankInGroup = function()
			error("group unavailable")
		end,
	}
end

T.describe("Dev solo play gate", function()
	T.it("allows only rank 254+ in the configured group", function()
		T.expect(DevSoloPlay.canUse(rankPlayer(254))):toEqual(true)
		T.expect(DevSoloPlay.canUse(rankPlayer(300))):toEqual(true)
		T.expect(DevSoloPlay.canUse(rankPlayer(253))):toEqual(false)
		T.expect(DevSoloPlay.canUse(rankPlayer(0))):toEqual(false)
	end)

	T.it("rejects players that cannot report a group rank", function()
		T.expect(DevSoloPlay.canUse(brokenPlayer())):toEqual(false)
		T.expect(DevSoloPlay.canUse({})):toEqual(false)
	end)

	T.it("rejects anything that is not a player-shaped value", function()
		T.expect(DevSoloPlay.canUse(nil)):toEqual(false)
		T.expect(DevSoloPlay.canUse(254)):toEqual(false)
		T.expect(DevSoloPlay.canUse("owner")):toEqual(false)
	end)
end)

return true
