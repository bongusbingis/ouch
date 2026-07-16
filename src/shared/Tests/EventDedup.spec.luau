--!strict

local T = require(script.Parent.TestKit)
local EventDedup = require(script.Parent.Parent.Game.Adapters.EventDedup)

local function event(overrides: { [string]: any }?): EventDedup.Event
	local base: EventDedup.Event = {
		kind = "HammerHit",
		tick = 12,
		playerId = "p1",
		sourceId = "p1",
		targetId = "p2",
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

T.describe("EventDedup", function()
	T.it("accepts an event once and rejects the repeat", function()
		local dedup = EventDedup.new()
		T.expect(dedup.markSeen(event())):toBeTruthy()
		T.expect(dedup.markSeen(event())):toEqual(false)
	end)

	T.it("distinguishes events by their identifying fields", function()
		local dedup = EventDedup.new()
		T.expect(dedup.markSeen(event())):toBeTruthy()
		T.expect(dedup.markSeen(event({ tick = 13 }))):toBeTruthy()
		T.expect(dedup.markSeen(event({ kind = "HammerMiss" }))):toBeTruthy()
		T.expect(dedup.markSeen(event({ targetId = "p3" }))):toBeTruthy()
	end)

	T.it("clear re-admits previously seen events", function()
		local dedup = EventDedup.new()
		T.expect(dedup.markSeen(event())):toBeTruthy()
		dedup.clear()
		T.expect(dedup.markSeen(event())):toBeTruthy()
	end)

	T.it("evicts history at the cap and keeps deduping new events", function()
		local dedup = EventDedup.new(2)
		T.expect(dedup.markSeen(event({ tick = 1 }))):toBeTruthy()
		T.expect(dedup.markSeen(event({ tick = 2 }))):toBeTruthy()
		T.expect(dedup.markSeen(event({ tick = 3 }))):toBeTruthy()
		T.expect(dedup.markSeen(event({ tick = 3 }))):toEqual(false)
	end)
end)

return true
