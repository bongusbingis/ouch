--!strict

local T = require(script.Parent.TestKit)
local Policy = require(script.Parent.Parent.Game.Matchmaking.ReturnQueuePolicy)
local payload = { partyId = "old", matchId = "match", memberUserIds = { 10, 20 }, queueOnArrival = true }
local function party()
	return { phase = "Lobby", leaderUserId = 10, members = { { userId = 10 }, { userId = 20 } } }
end

T.describe("ReturnQueuePolicy", function()
	T.it("waits for the whole returning party and its leader", function()
		local record = party()
		Policy.arm(record, payload, 100, 20)
		T.expect(Policy.evaluate(record, { [10] = true }, 101)):toEqual("Waiting")
		T.expect(Policy.evaluate(record, { [20] = true }, 101)):toEqual("Waiting")
		T.expect(Policy.evaluate(record, { [10] = true, [20] = true }, 101)):toEqual("Ready")
	end)
	T.it("expires at the deadline instead of partially moving a party", function()
		local record = party()
		Policy.arm(record, payload, 100, 20)
		T.expect(Policy.evaluate(record, { [10] = true, [20] = true }, 120)):toEqual("Expired")
	end)
	T.it("cannot re-arm a consumed or cancelled intent from a duplicate arrival", function()
		local record = party()
		Policy.arm(record, payload, 100, 20)
		record.returnQueue = nil
		Policy.arm(record, payload, 110, 20)
		T.expect(record.returnQueue):toBeNil()
		local nextPayload = table.clone(payload)
		nextPayload.matchId = "next"
		Policy.arm(record, nextPayload, 110, 20)
		T.expect(record.returnQueue.expiresAt):toEqual(130)
	end)
	T.it("does not queue an ordinary return or a party that has already queued", function()
		local record = party()
		local normal = table.clone(payload)
		normal.queueOnArrival = nil
		Policy.arm(record, normal, 100, 20)
		T.expect(Policy.evaluate(record, { [10] = true, [20] = true }, 101)):toEqual("None")
		normal.matchId = "second"
		normal.queueOnArrival = true
		Policy.arm(record, normal, 100, 20)
		record.phase = "Queued"
		T.expect(Policy.evaluate(record, { [10] = true, [20] = true }, 101)):toEqual("None")
	end)
	T.it("waits for expected members while rebuilding an expired party record", function()
		local record = party()
		table.remove(record.members, 2)
		Policy.arm(record, payload, 100, 20)
		T.expect(Policy.evaluate(record, { [10] = true, [20] = true }, 101)):toEqual("Waiting")
		T.expect(record.returnQueue.memberUserIds == payload.memberUserIds):toEqual(false)
	end)
	T.it("adopts the payload's queue when arming a fresh return intent", function()
		local record = party()
		local withQueue = table.clone(payload)
		withQueue.queueId = "Splashdown"
		Policy.arm(record, withQueue, 100, 20)
		T.expect(record.queueId):toEqual("Splashdown")
	end)
	T.it("leaves the record's queue untouched when the payload names none", function()
		local record = party()
		record.queueId = "Arena"
		Policy.arm(record, payload, 100, 20)
		T.expect(record.queueId):toEqual("Arena")
	end)
	T.it("cannot change the queue by re-arming a consumed intent", function()
		local record = party()
		Policy.arm(record, payload, 100, 20)
		record.queueId = "Arena"
		local withQueue = table.clone(payload)
		withQueue.queueId = "Splashdown"
		Policy.arm(record, withQueue, 110, 20)
		T.expect(record.queueId):toEqual("Arena")
	end)
end)

return true
