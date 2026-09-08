-- Description: Spec for the mode vote view model: vote count formatting and the clamped loading-bar fraction derived from server time.

--!strict

local T = require(script.Parent.TestKit)
local GameModeVoteViewModel = require(script.Parent.Parent.UI.Models.GameModeVoteViewModel)

T.describe("GameModeVoteViewModel", function()
	T.it("describes the resolved target instead of a stale configured sentence", function()
		T.expect(GameModeVoteViewModel.description({ ScoreTarget = 24 }, true))
			:toEqual("First team to 24 eliminations wins. Parties stay together.")
	end)
	T.it("labels vote counts and handles singular votes", function()
		T.expect(GameModeVoteViewModel.formatVoteCount(0)):toEqual("0 VOTES")
		T.expect(GameModeVoteViewModel.formatVoteCount(1)):toEqual("1 VOTE")
		T.expect(GameModeVoteViewModel.formatVoteCount(20)):toEqual("20 VOTES")
	end)

	T.it("derives a clamped loading-bar fraction from server time", function()
		T.expect(GameModeVoteViewModel.progress(10, 20, 10)):toEqual(1)
		T.expect(GameModeVoteViewModel.progress(15, 20, 10)):toEqual(0.5)
		T.expect(GameModeVoteViewModel.progress(25, 20, 10)):toEqual(0)
		T.expect(GameModeVoteViewModel.progress(10, 20, 0)):toEqual(0)
	end)
end)

return true
