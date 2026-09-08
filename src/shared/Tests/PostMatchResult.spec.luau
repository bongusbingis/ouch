-- Description: Spec for the post-match result projection: deterministic score ordering with shared placements, victory derived from team membership, absent rather than fabricated fields, and rejection of malformed packets.

--!strict

local T = require(script.Parent.TestKit)
local PostMatchResult = require(script.Parent.Parent.Game.PostMatch.PostMatchResult)

local function global(modeId: string, scope: "Player" | "Team", winnerId: string?)
	return PostMatchResult.build({
		resultId = "result-1",
		modeId = modeId,
		modeName = if modeId == "FFA" then "Free For All" else "Team Deathmatch",
		scoreScope = scope,
		winnerId = winnerId,
		reason = "TargetReached",
		interactiveAt = 10,
		endsAt = 18,
		contestants = {
			{ playerId = "10", userId = 10, username = "One", displayName = "ONE", teamId = "Blue" },
			{ playerId = "20", userId = 20, username = "Two", displayName = "TWO", teamId = "Red" },
			{ playerId = "30", userId = 30, username = "Three", displayName = "THREE", teamId = "Blue" },
		},
		scores = if scope == "Team" then { Blue = 25, Red = 18 } else { ["10"] = 15, ["20"] = 7, ["30"] = 7 },
		teamIds = if scope == "Team" then { "Red", "Blue" } else nil,
	})
end

T.describe("PostMatchResult", function()
	T.it("explains opponent loss without claiming that a tied contest was completed", function()
		local result = global("TDM", "Team", nil)
		result.reason = "NoContest"
		local projected = PostMatchResult.forPlayer(result, 10, nil, nil)
		T.expect(projected.outcome):toEqual("RoundOver")
		T.expect(projected.presentation.title):toEqual("LET'S FIND MORE PLAYERS")
		T.expect(#projected.podium):toEqual(0)
	end)
	T.it("retains earned standings for a contestant whose live score entry was removed", function()
		local result = PostMatchResult.build({
			resultId = "round",
			modeId = "FFA",
			modeName = "Free For All",
			scoreScope = "Player",
			reason = "TimeCap",
			interactiveAt = 10,
			endsAt = 20,
			contestants = {
				{ playerId = "10", userId = 10, username = "Left", displayName = "LEFT", contribution = 8 },
				{ playerId = "20", userId = 20, username = "Here", displayName = "HERE", contribution = 3 },
			},
			scores = { ["20"] = 3 },
		})
		T.expect(result.scores[1].id):toEqual("10")
		T.expect(result.scores[1].score):toEqual(8)
		T.expect(result.winnerId):toBeNil()
	end)
	T.it("does not declare a winner when the authoritative round is tied", function()
		local result = global("FFA", "Player", nil)
		result.scores[1].score = result.scores[2].score
		local projected = PostMatchResult.forPlayer(result, 10, nil, nil)
		T.expect(projected.outcome):toEqual("RoundOver")
		T.expect(projected.presentation.detail):toEqual("TIED ROUND")
	end)

	T.it("projects bounded podium ranks without breaking ties or rewarding ownership", function()
		local result = global("FFA", "Player", "10")
		result.contestants[2].emoteId = "ShowtimeTwirl"
		result.contestants[2].costumeId = "PartyRoyal"
		local projected = PostMatchResult.forPlayer(result, 20, nil, nil)
		T.expect(#projected.podium):toEqual(3)
		T.expect(projected.podium[1].userId):toEqual(10)
		T.expect(projected.podium[2].placement):toEqual(2)
		T.expect(projected.podium[3].placement):toEqual(2)
		T.expect(projected.personalAppearance.emoteId):toEqual("ShowtimeTwirl")
		T.expect(projected.personalAppearance.costumeId):toEqual("PartyRoyal")
		local parsed = PostMatchResult.parse(projected)
		T.expect(parsed.podium[2].emoteId):toEqual("ShowtimeTwirl")
		T.expect(parsed.podium[2].costumeId):toEqual("PartyRoyal")
		projected.podium[2].emoteId = "Changed"
		projected.podium[2].costumeId = "RainHopper"
		T.expect(parsed.podium[2].emoteId):toEqual("ShowtimeTwirl")
		T.expect(parsed.podium[2].costumeId):toEqual("PartyRoyal")
		projected.podium[3] = projected.podium[2]
		T.expect(PostMatchResult.parse(projected)):toBeNil()
	end)

	T.it("keeps team contribution recognition separate from the winning team score", function()
		local result = global("TDM", "Team", "Blue")
		result.contestants[1].contribution = 8
		result.contestants[2].contribution = 15
		result.contestants[3].contribution = 17
		local podium = PostMatchResult.podium(result)
		T.expect(#podium):toEqual(2)
		T.expect(podium[1].userId):toEqual(30)
		T.expect(podium[1].score):toEqual(17)
		T.expect(result.scores[1].score):toEqual(25)
	end)
	T.it("accepts default cosmetic attribute projections without inventing equips", function()
		local result = global("FFA", "Player", "10")
		result.contestants[1].emoteId = ""
		result.contestants[1].colorId = ""
		result.contestants[1].costumeId = ""
		local projected = PostMatchResult.forPlayer(result, 10, nil, nil)
		local parsed = PostMatchResult.parse(projected)
		T.expect(parsed.personalAppearance.emoteId):toBeNil()
		T.expect(parsed.podium[1].colorId):toBeNil()
		T.expect(parsed.podium[1].costumeId):toBeNil()
	end)

	T.it("orders FFA scores deterministically and assigns shared placements", function()
		local result = global("FFA", "Player", "10")
		T.expect(result.scores[1].id):toEqual("10")
		T.expect(result.scores[1].placement):toEqual(1)
		T.expect(result.scores[2].score):toEqual(7)
		T.expect(result.scores[2].placement):toEqual(2)
		T.expect(result.scores[3].placement):toEqual(2)
	end)

	T.it("projects victory and defeat from authoritative team membership", function()
		local result = global("TDM", "Team", "Blue")
		local winner = PostMatchResult.forPlayer(result, 10, nil, nil)
		local loser = PostMatchResult.forPlayer(result, 20, nil, nil)
		T.expect((winner :: any).outcome):toEqual("Victory")
		T.expect((loser :: any).outcome):toEqual("Defeat")
		T.expect((winner :: any).presentation.title):toEqual("BLUE TEAM WINS!")
	end)

	T.it("keeps unavailable rewards absent and exposes only tracked statistics", function()
		local result = global("FFA", "Player", "10")
		local withoutRewards = PostMatchResult.forPlayer(result, 10, { elims = 4, catches = 2 }, nil)
		T.expect((withoutRewards :: any).rewards):toBeNil()
		T.expect(#(withoutRewards :: any).personalStats):toEqual(3)
		T.expect((withoutRewards :: any).personalStats[1].highlight):toBeTruthy()
	end)

	T.it("uses real reward and season deltas without changing them", function()
		local result = global("FFA", "Player", "10")
		local playerResult = PostMatchResult.forPlayer(result, 10, {
			firstMatch = true,
			xp = 125,
			bonks = 20,
			seasonXp = 125,
			seasonBefore = { active = true, seasonId = "s1", xp = 200, tier = 2 },
			seasonAfter = {
				active = true,
				seasonId = "s1",
				displayName = "SEASON ONE",
				xp = 325,
				tier = 3,
				xpIntoTier = 25,
				xpForNextTier = 100,
			},
		}, nil)
		T.expect((playerResult :: any).rewards.matchXp):toEqual(125)
		T.expect((playerResult :: any).firstMatch):toBeTruthy()
		T.expect((playerResult :: any).seasonProgress.beforeTier):toEqual(2)
		T.expect((playerResult :: any).seasonProgress.afterTier):toEqual(3)
	end)

	T.it("formats ordinal placements and rejects malformed packets", function()
		T.expect(PostMatchResult.formatPlacement(1)):toEqual("1ST")
		T.expect(PostMatchResult.formatPlacement(12)):toEqual("12TH")
		T.expect(PostMatchResult.formatPlacement(23)):toEqual("23RD")
		T.expect(PostMatchResult.parse({ schemaVersion = 99 })):toBeNil()
	end)

	T.it("copies rendered packet data and rejects malformed nested entries", function()
		local projected = PostMatchResult.forPlayer(global("FFA", "Player", "10"), 10, { xp = 20, bonks = 5 }, {
			partyId = "party-1",
			leaderUserId = 10,
			members = {
				{
					userId = 10,
					username = "One",
					displayName = "ONE",
					isLeader = true,
					isLocal = true,
					present = true,
				},
			},
		})
		local parsed = PostMatchResult.parse(projected)
		T.expect(parsed ~= nil):toBeTruthy()
		local rawProjected: any = projected
		rawProjected.scores[1].label = "CHANGED"
		T.expect((parsed :: any).scores[1].label == "CHANGED"):toEqual(false)

		local malformed = table.clone(projected :: any)
		malformed.personalStats = { { id = "Elims", label = "ELIMINATIONS", value = 0 / 0 } }
		T.expect(PostMatchResult.parse(malformed)):toBeNil()
	end)
end)

return true
