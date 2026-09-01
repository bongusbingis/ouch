-- Name: ModeVote.spec.luau
-- Author: Jack C.
-- Description: Spec for the pure ballot: one vote per player, removal of departed voters, random selection when nobody votes or leaders tie, and the capped late-ready extension.
-- Created: 2026-08-17

--!strict

local T = require(script.Parent.TestKit)
local ModeVote = require(script.Parent.Parent.Game.Modes.ModeVote)

T.describe("ModeVote", function()
	T.it("replaces one ballot per player and removes departed ballots", function()
		local state = ModeVote.new({ "FFA", "TDM" })
		T.expect(ModeVote.cast(state, 1, "FFA")):toBeTruthy()
		T.expect(not ModeVote.cast(state, 1, "FFA")):toBeTruthy()
		T.expect(ModeVote.cast(state, 1, "TDM")):toBeTruthy()
		T.expect(not ModeVote.cast(state, 2, "missing")):toBeTruthy()

		local counts = ModeVote.counts(state)
		T.expect(counts.FFA):toEqual(0)
		T.expect(counts.TDM):toEqual(1)
		T.expect(ModeVote.remove(state, 1)):toBeTruthy()
		T.expect(not ModeVote.remove(state, 1)):toBeTruthy()
		T.expect(ModeVote.counts(state).TDM):toEqual(0)
	end)

	T.it("reports all voted only once every listed voter has a ballot", function()
		local state = ModeVote.new({ "FFA", "TDM" })
		T.expect(not ModeVote.allVoted(state, { 1, 2 })):toBeTruthy()
		ModeVote.cast(state, 1, "FFA")
		T.expect(not ModeVote.allVoted(state, { 1, 2 })):toBeTruthy()
		ModeVote.cast(state, 2, "TDM")
		T.expect(ModeVote.allVoted(state, { 1, 2 })):toBeTruthy()
		T.expect(not ModeVote.allVoted(state, { 1, 2, 3 })):toBeTruthy()
		T.expect(not ModeVote.allVoted(state, {})):toBeTruthy()
	end)

	T.it("selects from all options when nobody votes", function()
		local state = ModeVote.new({ "FFA", "TDM" })
		T.expect(table.concat(ModeVote.finalists(state), ",")):toEqual("FFA,TDM")
		local winner = ModeVote.choose(state, function()
			return 2
		end)
		T.expect(winner == "FFA" or winner == "TDM"):toBeTruthy()
	end)

	T.it("selects only among tied leaders", function()
		local state = ModeVote.new({ "FFA", "TDM", "Infection" })
		ModeVote.cast(state, 1, "FFA")
		ModeVote.cast(state, 2, "TDM")
		T.expect(table.concat(ModeVote.finalists(state), ",")):toEqual("FFA,TDM")
		for index = 1, 2 do
			T.expect(ModeVote.choose(state, function()
				return index
			end) ~= "Infection"):toBeTruthy()
		end
	end)

	T.it("gives late-ready players a minimum visible window within the extension cap", function()
		T.expect(ModeVote.extendForLateReady(110, 120, 108, 5)):toEqual(113)
		T.expect(ModeVote.extendForLateReady(119, 120, 118, 5)):toEqual(120)
		T.expect(ModeVote.extendForLateReady(110, 120, 104, 5)):toEqual(110)
		T.expect(ModeVote.extendForLateReady(110, 120, 110, 5)):toEqual(110)
	end)
end)

return true
