-- Award journal limits must never discard uncommitted rewards.
--!strict

local T = require(script.Parent.TestKit)
local MatchAwards = require(script.Parent.Parent.Game.Progression.MatchAwards)

T.describe("MatchAwards", function()
	T.it("migrates old profiles without replacing existing rewards", function()
		local data: any = { Bonks = 125 }
		local journal = MatchAwards.ensure(data)
		T.expect(journal.Version):toEqual(1)
		T.expect(data.Bonks):toEqual(125)
		MatchAwards.enqueue(journal, "one", { Ready = false }, 2)
		T.expect(MatchAwards.ensure(data).Pending.one.Ready):toEqual(false)
	end)
	T.it("rejects capacity overflow without evicting pending entries", function()
		local journal = MatchAwards.ensure({})
		MatchAwards.enqueue(journal, "one", { XP = 100 }, 1)
		T.expect(MatchAwards.enqueue(journal, "two", { XP = 200 }, 1)):toBeNil()
		T.expect(journal.Pending.one.XP):toEqual(100)
	end)
	T.it("deduplicates completed awards and bounds completion history", function()
		local journal = MatchAwards.ensure({})
		for index = 1, 5 do
			local id = tostring(index)
			MatchAwards.enqueue(journal, id, {}, 2)
			MatchAwards.complete(journal, id, index, 2)
		end
		T.expect(journal.Completed["3"]):toBeNil()
		T.expect(journal.Completed["4"]):toEqual(4)
		T.expect(MatchAwards.enqueue(journal, "5", {}, 2)):toBeNil()
		T.expect(next(journal.Pending)):toBeNil()
	end)
end)

return true
