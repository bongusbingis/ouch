-- Description: In-place port of the event dedup spec: single admission, identity fields, clearing, and eviction at the cap.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local EventDedup = require(Shared:WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("EventDedup"))

local function event(overrides)
	local base = {
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

return function()
	describe("EventDedup", function()
		it("accepts an event once and rejects the repeat", function()
			local dedup = EventDedup.new()
			expect(dedup.markSeen(event())).to.equal(true)
			expect(dedup.markSeen(event())).to.equal(false)
		end)

		it("distinguishes events by their identifying fields", function()
			local dedup = EventDedup.new()
			expect(dedup.markSeen(event())).to.equal(true)
			expect(dedup.markSeen(event({ tick = 13 }))).to.equal(true)
			expect(dedup.markSeen(event({ kind = "HammerMiss" }))).to.equal(true)
			expect(dedup.markSeen(event({ targetId = "p3" }))).to.equal(true)
		end)

		it("clear re-admits previously seen events", function()
			local dedup = EventDedup.new()
			expect(dedup.markSeen(event())).to.equal(true)
			dedup.clear()
			expect(dedup.markSeen(event())).to.equal(true)
		end)

		it("evicts history at the cap and keeps deduping new events", function()
			local dedup = EventDedup.new(2)
			expect(dedup.markSeen(event({ tick = 1 }))).to.equal(true)
			expect(dedup.markSeen(event({ tick = 2 }))).to.equal(true)
			expect(dedup.markSeen(event({ tick = 3 }))).to.equal(true)
			expect(dedup.markSeen(event({ tick = 3 }))).to.equal(false)
		end)

		it("keeps separate histories per instance", function()
			local dedupA = EventDedup.new()
			local dedupB = EventDedup.new()
			expect(dedupA.markSeen(event())).to.equal(true)
			expect(dedupB.markSeen(event())).to.equal(true)
			expect(dedupA.markSeen(event())).to.equal(false)
			expect(dedupB.markSeen(event())).to.equal(false)
		end)
	end)
end
