-- Name: QuestLogic.spec.luau
-- Author: Jack C.
-- Description: Spec for the pure quest rules: deterministic daily ids, UTC daily keys and reset times, event-to-progress mapping, and clamped public payloads.
-- Created: 2026-07-13

--!strict

local T = require(script.Parent.TestKit)
local QuestLogic = require(script.Parent.Parent.Game.Quests.QuestLogic)

local definitions = {
	{
		id = "a_elims",
		title = "Elims",
		goal = 5,
		steps = 5,
		reward = { kind = "Bonks", amount = 100 },
		track = { kind = "Elim" },
	},
	{
		id = "b_catches",
		title = "Catches",
		goal = 3,
		steps = 3,
		reward = { kind = "Bonks", amount = 100 },
		track = { kind = "Catch" },
	},
	{
		id = "c_matches",
		title = "Matches",
		goal = 2,
		steps = 2,
		reward = { kind = "Bonks", amount = 100 },
		track = { kind = "MatchPlayed" },
	},
	{
		id = "d_tdm",
		title = "TDM",
		goal = 1,
		steps = 1,
		reward = { kind = "Bonks", amount = 100 },
		track = { kind = "ModeWin", modeId = "TDM" },
	},
}

T.describe("QuestLogic", function()
	T.it("generates deterministic daily quest ids", function()
		local first = QuestLogic.selectDailyQuestIds(123, "2026-07-13", definitions, 3)
		local second = QuestLogic.selectDailyQuestIds(123, "2026-07-13", definitions, 3)

		T.expect(#first):toEqual(3)
		T.expect(first[1]):toEqual(second[1])
		T.expect(first[2]):toEqual(second[2])
		T.expect(first[3]):toEqual(second[3])
	end)

	T.it("computes daily keys and reset timestamps in UTC", function()
		local now = 1783956600

		T.expect(QuestLogic.dailyKey(now)):toEqual("2026-07-13")
		T.expect(QuestLogic.nextResetAt(now)):toEqual(1783987200)
	end)

	T.it("maps event progress to the intended player and mode", function()
		local byId = QuestLogic.definitionsById(definitions)
		local elim = { kind = "Elim", sourceId = "1", targetId = "2" }
		local catch = { kind = "BallCaught", playerId = "1" }
		local tdmWin = { kind = "MatchEnded" }

		T.expect(QuestLogic.progressForEvent(byId.a_elims, elim, { playerId = "1" })):toEqual(1)
		T.expect(QuestLogic.progressForEvent(byId.a_elims, elim, { playerId = "2" })):toEqual(0)
		T.expect(QuestLogic.progressForEvent(byId.b_catches, catch, { playerId = "1" })):toEqual(1)
		T.expect(QuestLogic.progressForEvent(byId.d_tdm, tdmWin, {
			playerId = "1",
			modeId = "TDM",
			playerWon = true,
		})):toEqual(1)
		T.expect(QuestLogic.progressForEvent(byId.d_tdm, tdmWin, {
			playerId = "1",
			modeId = "FFA",
			playerWon = true,
		})):toEqual(0)
	end)

	T.it("builds clamped public quest payloads", function()
		local payload = QuestLogic.publicQuest(definitions[1], {
			id = "a_elims",
			progress = 9,
			claimed = false,
		}, 2)

		T.expect(payload.slot):toEqual(2)
		T.expect(payload.progress):toEqual(5)
		T.expect(payload.completed):toEqual(true)
		T.expect(payload.reward.amount):toEqual(100)
	end)
end)

return true
