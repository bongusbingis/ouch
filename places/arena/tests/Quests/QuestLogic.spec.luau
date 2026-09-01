-- Name: QuestLogic.spec.luau
-- Author: Jack C.
-- Description: In-place port of the quest logic spec, covering deterministic daily selection, UTC reset keys, event-to-progress mapping, and clamped public payloads.
-- Created: 2026-07-16

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local QuestLogic = require(Shared:WaitForChild("Game"):WaitForChild("Quests"):WaitForChild("QuestLogic"))

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

return function()
	describe("QuestLogic", function()
		it("generates deterministic daily quest ids", function()
			local first = QuestLogic.selectDailyQuestIds(123, "2026-07-13", definitions, 3)
			local second = QuestLogic.selectDailyQuestIds(123, "2026-07-13", definitions, 3)

			expect(#first).to.equal(3)
			expect(first[1]).to.equal(second[1])
			expect(first[2]).to.equal(second[2])
			expect(first[3]).to.equal(second[3])
		end)

		it("selects distinct quest ids that all come from the definitions", function()
			local byId = QuestLogic.definitionsById(definitions)
			local selected = QuestLogic.selectDailyQuestIds(456, "2026-07-13", definitions, 3)
			local seen = {}
			for _, id in selected do
				expect(byId[id]).to.be.ok()
				expect(seen[id]).never.to.be.ok()
				seen[id] = true
			end
		end)

		it("computes daily keys and reset timestamps in UTC", function()
			local now = 1783956600

			expect(QuestLogic.dailyKey(now)).to.equal("2026-07-13")
			expect(QuestLogic.nextResetAt(now)).to.equal(1783987200)
		end)

		it("rolls the daily key exactly at the UTC midnight boundary", function()
			local midnight = 1783987200

			expect(QuestLogic.dailyKey(midnight - 1)).to.equal("2026-07-13")
			expect(QuestLogic.dailyKey(midnight)).to.equal("2026-07-14")
			expect(QuestLogic.nextResetAt(midnight)).to.equal(midnight + 86400)
		end)

		it("maps event progress to the intended player and mode", function()
			local byId = QuestLogic.definitionsById(definitions)
			local elim = { kind = "Elim", sourceId = "1", targetId = "2" }
			local catch = { kind = "BallCaught", playerId = "1" }
			local tdmWin = { kind = "MatchEnded" }

			expect(QuestLogic.progressForEvent(byId.a_elims, elim, { playerId = "1" })).to.equal(1)
			expect(QuestLogic.progressForEvent(byId.a_elims, elim, { playerId = "2" })).to.equal(0)
			expect(QuestLogic.progressForEvent(byId.b_catches, catch, { playerId = "1" })).to.equal(1)
			expect(QuestLogic.progressForEvent(byId.d_tdm, tdmWin, {
				playerId = "1",
				modeId = "TDM",
				playerWon = true,
			})).to.equal(1)
			expect(QuestLogic.progressForEvent(byId.d_tdm, tdmWin, {
				playerId = "1",
				modeId = "FFA",
				playerWon = true,
			})).to.equal(0)
		end)

		it("builds clamped public quest payloads", function()
			local payload = QuestLogic.publicQuest(definitions[1], {
				id = "a_elims",
				progress = 9,
				claimed = false,
			}, 2)

			expect(payload.slot).to.equal(2)
			expect(payload.progress).to.equal(5)
			expect(payload.completed).to.equal(true)
			expect(payload.reward.amount).to.equal(100)
		end)
	end)
end
