-- Description: Spec for quest daily rollover: UTC reset times across month, year, and leap-day boundaries, reset detection on repeated same-day calls, and the one-time payout of completed unclaimed quests.

--!strict

local T = require(script.Parent.TestKit)
local QuestLogic = require(script.Parent.Parent.Game.Quests.QuestLogic)

local DAY = 86400
local HALF_DAY = 43200

local definitions: { QuestLogic.QuestDefinition } = {
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
}

-- UTC midnight of each date.
local JAN_30_2026 = 1769731200
local JAN_31_2026 = 1769817600
local FEB_01_2026 = 1769904000
local FEB_28_2026 = 1772236800
local MAR_01_2026 = 1772323200
local FEB_28_2028 = 1835308800
local FEB_29_2028 = 1835395200
local MAR_01_2028 = 1835481600
local OCT_31_2026 = 1793404800
local NOV_01_2026 = 1793491200
local NOV_30_2026 = 1795996800
local DEC_01_2026 = 1796083200
local DEC_31_2026 = 1798675200
local JAN_01_2027 = 1798761600

-- Simulates QuestService.ensureData: reset only when needed, collect what the
-- old set still owes, then replace the set. Returns how many rewards paid out.
local function ensureDaily(quests: { [string]: any }, now: number): number
	if not QuestLogic.needsDailyReset(quests.DailyKey, quests.ResetAt, now) then
		return 0
	end
	local byId = QuestLogic.definitionsById(definitions)
	local owed = QuestLogic.completedUnclaimed(QuestLogic.copyEntries(quests.Active), byId)
	local state = QuestLogic.createDailyEntries(42, now, definitions, 3)
	quests.DailyKey = state.dailyKey
	quests.ResetAt = state.resetAt
	quests.Active = state.active
	return #owed
end

local function completeAll(quests: { [string]: any })
	local byId = QuestLogic.definitionsById(definitions)
	for _, entry in quests.Active do
		entry.progress = byId[entry.id].goal
	end
end

T.describe("QuestLogic rollover", function()
	T.it("resets at the next UTC midnight on the last day of every month", function()
		local cases = {
			{ JAN_31_2026, FEB_01_2026 },
			{ FEB_28_2026, MAR_01_2026 },
			{ FEB_28_2028, FEB_29_2028 },
			{ FEB_29_2028, MAR_01_2028 },
			{ OCT_31_2026, NOV_01_2026 },
			{ NOV_30_2026, DEC_01_2026 },
			{ DEC_31_2026, JAN_01_2027 },
		}
		for _, case in cases do
			local dayStart, nextDay = case[1], case[2]
			T.expect(QuestLogic.nextResetAt(dayStart)):toEqual(nextDay)
			T.expect(QuestLogic.nextResetAt(dayStart + HALF_DAY)):toEqual(nextDay)
			T.expect(QuestLogic.nextResetAt(nextDay - 1)):toEqual(nextDay)
		end
	end)

	T.it("builds daily state on month and year end days without erroring", function()
		local yearEnd = QuestLogic.createDailyEntries(42, DEC_31_2026 + HALF_DAY, definitions, 3)
		T.expect(yearEnd.dailyKey):toEqual("2026-12-31")
		T.expect(yearEnd.resetAt):toEqual(JAN_01_2027)
		T.expect(#yearEnd.active):toEqual(3)

		local leapDay = QuestLogic.blankState(FEB_29_2028 + HALF_DAY)
		T.expect(leapDay.dailyKey):toEqual("2028-02-29")
		T.expect(leapDay.resetAt):toEqual(MAR_01_2028)
	end)

	T.it("needs a reset only when the UTC day or reset time has passed", function()
		local state = QuestLogic.createDailyEntries(42, JAN_31_2026 + HALF_DAY, definitions, 3)
		T.expect(QuestLogic.needsDailyReset(state.dailyKey, state.resetAt, JAN_31_2026 + HALF_DAY)):toEqual(false)
		T.expect(QuestLogic.needsDailyReset(state.dailyKey, state.resetAt, FEB_01_2026 - 1)):toEqual(false)
		T.expect(QuestLogic.needsDailyReset(state.dailyKey, state.resetAt, FEB_01_2026)):toEqual(true)
		T.expect(QuestLogic.needsDailyReset(nil, state.resetAt, JAN_31_2026)):toEqual(true)
		T.expect(QuestLogic.needsDailyReset(state.dailyKey, nil, JAN_31_2026)):toEqual(true)
	end)

	T.it("pays completed unclaimed quests once when rolling into the last day of a month", function()
		local boundaries = {
			{ JAN_30_2026, JAN_31_2026 },
			{ JAN_31_2026, FEB_01_2026 },
			{ FEB_28_2026 - DAY, FEB_28_2026 },
			{ FEB_28_2028, FEB_29_2028 },
			{ NOV_30_2026 - DAY, NOV_30_2026 },
			{ DEC_31_2026 - DAY, DEC_31_2026 },
			{ DEC_31_2026, JAN_01_2027 },
		}
		for _, boundary in boundaries do
			local previousDay, rolloverDay = boundary[1], boundary[2]
			local quests: { [string]: any } = {}
			T.expect(ensureDaily(quests, previousDay + HALF_DAY)):toEqual(0)
			completeAll(quests)

			T.expect(ensureDaily(quests, rolloverDay + 1)):toEqual(3)
			T.expect(quests.DailyKey):toEqual(QuestLogic.dailyKey(rolloverDay))
			T.expect(quests.ResetAt):toEqual(rolloverDay + DAY)

			for _ = 1, 5 do
				T.expect(ensureDaily(quests, rolloverDay + HALF_DAY)):toEqual(0)
			end
			T.expect(quests.DailyKey):toEqual(QuestLogic.dailyKey(rolloverDay))
		end
	end)

	T.it("owes nothing for claimed or incomplete entries", function()
		local byId = QuestLogic.definitionsById(definitions)
		local owed = QuestLogic.completedUnclaimed({
			{ id = "a_elims", progress = 5, claimed = true },
			{ id = "b_catches", progress = 2, claimed = false },
			{ id = "c_matches", progress = 2, claimed = false },
			{ id = "retired_quest", progress = 99, claimed = false },
		}, byId)
		T.expect(#owed):toEqual(1)
		T.expect(owed[1].id):toEqual("c_matches")
	end)
end)

return true
