-- Name: DailyRewardLogic.spec.luau
-- Author: Jack C.
-- Description: Spec for the pure daily reward rules: UTC-day gating, cycle progression, claim legality, and public state construction.
-- Created: 2026-09-01

--!strict

local T = require(script.Parent.TestKit)
local DailyRewardLogic = require(script.Parent.Parent.Game.DailyReward.DailyRewardLogic)

local CONFIG = {
	CycleLength = 7,
	Rewards = {
		[1] = { kind = "Bonks", amount = 100 },
		[2] = { kind = "Bonks", amount = 125 },
		[3] = { kind = "Bonks", amount = 150 },
		[4] = { kind = "Bonks", amount = 200 },
		[5] = { kind = "Bonks", amount = 250 },
		[6] = { kind = "Bonks", amount = 300 },
		[7] = { kind = "Bonks", amount = 500 },
	},
}

-- 2026-09-01 12:00:00 UTC
local NOON = 1788264000
-- 2026-09-02 12:00:00 UTC
local NEXT_NOON = NOON + 86400

T.describe("DailyRewardLogic", function()
	T.it("blankState returns zeroed fields", function()
		local state = DailyRewardLogic.blankState()
		T.expect(state.Day):toEqual(0)
		T.expect(state.LastClaimAt):toEqual(0)
		T.expect(state.TotalClaimed):toEqual(0)
	end)

	T.it("readState normalizes nil and non-table inputs", function()
		local state = DailyRewardLogic.readState(nil)
		T.expect(state.Day):toEqual(0)
		T.expect(state.LastClaimAt):toEqual(0)

		local fromString = DailyRewardLogic.readState("garbage")
		T.expect(fromString.Day):toEqual(0)
	end)

	T.it("readState preserves valid fields", function()
		local state = DailyRewardLogic.readState({ Day = 3, LastClaimAt = 1000, TotalClaimed = 5 })
		T.expect(state.Day):toEqual(3)
		T.expect(state.LastClaimAt):toEqual(1000)
		T.expect(state.TotalClaimed):toEqual(5)
	end)

	T.it("canClaim is true on first ever join", function()
		local state = DailyRewardLogic.blankState()
		T.expect(DailyRewardLogic.canClaim(state, NOON)):toEqual(true)
	end)

	T.it("canClaim is false if already claimed today", function()
		local state = { Day = 1, LastClaimAt = NOON, TotalClaimed = 1 }
		T.expect(DailyRewardLogic.canClaim(state, NOON + 3600)):toEqual(false)
	end)

	T.it("canClaim is true on the next UTC day", function()
		local state = { Day = 1, LastClaimAt = NOON, TotalClaimed = 1 }
		T.expect(DailyRewardLogic.canClaim(state, NEXT_NOON)):toEqual(true)
	end)

	T.it("nextDay advances from 0 to 1", function()
		local state = DailyRewardLogic.blankState()
		T.expect(DailyRewardLogic.nextDay(state, CONFIG)):toEqual(1)
	end)

	T.it("nextDay advances sequentially", function()
		T.expect(DailyRewardLogic.nextDay({ Day = 1, LastClaimAt = 0, TotalClaimed = 0 }, CONFIG)):toEqual(2)
		T.expect(DailyRewardLogic.nextDay({ Day = 5, LastClaimAt = 0, TotalClaimed = 0 }, CONFIG)):toEqual(6)
	end)

	T.it("nextDay wraps from 7 back to 1", function()
		T.expect(DailyRewardLogic.nextDay({ Day = 7, LastClaimAt = 0, TotalClaimed = 0 }, CONFIG)):toEqual(1)
	end)

	T.it("claim advances day and returns correct reward", function()
		local state = DailyRewardLogic.blankState()
		local newState, result = DailyRewardLogic.claim(state, CONFIG, NOON)
		assert(newState ~= nil, "newState should not be nil")
		assert(result ~= nil, "result should not be nil")
		T.expect(newState.Day):toEqual(1)
		T.expect(newState.LastClaimAt):toEqual(NOON)
		T.expect(newState.TotalClaimed):toEqual(1)
		T.expect(result.day):toEqual(1)
		T.expect(result.reward.kind):toEqual("Bonks")
		T.expect(result.reward.amount):toEqual(100)
	end)

	T.it("claim progresses through the full cycle", function()
		local state = DailyRewardLogic.blankState()
		local time = NOON
		for day = 1, 7 do
			local newState, result = DailyRewardLogic.claim(state, CONFIG, time)
			assert(newState ~= nil and result ~= nil, `claim on day {day} should succeed`)
			T.expect(result.day):toEqual(day)
			T.expect(newState.TotalClaimed):toEqual(day)
			state = newState
			time = time + 86400
		end
		T.expect(state.Day):toEqual(7)
	end)

	T.it("claim wraps to day 1 after completing day 7", function()
		local state = { Day = 7, LastClaimAt = NOON, TotalClaimed = 7 }
		local newState, result = DailyRewardLogic.claim(state, CONFIG, NEXT_NOON)
		assert(newState ~= nil and result ~= nil, "claim should succeed")
		T.expect(newState.Day):toEqual(1)
		T.expect(result.day):toEqual(1)
		T.expect(result.reward.amount):toEqual(100)
		T.expect(newState.TotalClaimed):toEqual(8)
	end)

	T.it("claim returns nil when not claimable", function()
		local state = { Day = 1, LastClaimAt = NOON, TotalClaimed = 1 }
		local newState, result = DailyRewardLogic.claim(state, CONFIG, NOON + 100)
		T.expect(newState):toBeNil()
		T.expect(result):toBeNil()
	end)

	T.it("publicState marks days correctly for fresh player", function()
		local state = DailyRewardLogic.blankState()
		local pub = DailyRewardLogic.publicState(state, CONFIG, NOON)
		T.expect(pub.canClaim):toEqual(true)
		T.expect(pub.currentDay):toEqual(0)
		T.expect(pub.nextDay):toEqual(1)
		T.expect(#pub.days):toEqual(7)
		T.expect(pub.days[1].available):toEqual(true)
		T.expect(pub.days[1].claimed):toEqual(false)
		T.expect(pub.days[2].available):toEqual(false)
		T.expect(pub.days[2].claimed):toEqual(false)
	end)

	T.it("publicState marks claimed days after progress", function()
		local state = { Day = 3, LastClaimAt = NOON, TotalClaimed = 3 }
		local pub = DailyRewardLogic.publicState(state, CONFIG, NEXT_NOON)
		T.expect(pub.canClaim):toEqual(true)
		T.expect(pub.nextDay):toEqual(4)
		T.expect(pub.days[1].claimed):toEqual(true)
		T.expect(pub.days[2].claimed):toEqual(true)
		T.expect(pub.days[3].claimed):toEqual(true)
		T.expect(pub.days[4].claimed):toEqual(false)
		T.expect(pub.days[4].available):toEqual(true)
		T.expect(pub.days[4].current):toEqual(true)
	end)

	T.it("secondsUntilReset returns correct remaining time", function()
		-- NOON is 12:00:00 UTC, so 12 hours remain
		local seconds = DailyRewardLogic.secondsUntilReset(NOON)
		T.expect(seconds):toEqual(43200)
	end)

	T.it("dailyKey returns UTC date string", function()
		local key = DailyRewardLogic.dailyKey(NOON)
		T.expect(key):toEqual("2026-09-01")
	end)

	T.it("progress persists across missed days", function()
		local state = { Day = 3, LastClaimAt = NOON, TotalClaimed = 3 }
		-- Skip several days, come back
		local laterTime = NOON + 86400 * 5
		T.expect(DailyRewardLogic.canClaim(state, laterTime)):toEqual(true)
		local newState, result = DailyRewardLogic.claim(state, CONFIG, laterTime)
		assert(newState ~= nil and result ~= nil, "claim should succeed after gap")
		T.expect(result.day):toEqual(4)
		T.expect(newState.Day):toEqual(4)
	end)
end)

return true
