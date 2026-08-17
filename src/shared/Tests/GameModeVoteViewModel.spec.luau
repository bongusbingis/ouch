--!strict

local T = require(script.Parent.TestKit)
local GameModeVoteViewModel = require(script.Parent.Parent.UI.Models.GameModeVoteViewModel)

T.describe("GameModeVoteViewModel", function()
	T.it("formats vote counts with three digits", function()
		T.expect(GameModeVoteViewModel.formatVoteCount(0)):toEqual("000")
		T.expect(GameModeVoteViewModel.formatVoteCount(1)):toEqual("001")
		T.expect(GameModeVoteViewModel.formatVoteCount(20)):toEqual("020")
	end)

	T.it("derives a clamped loading-bar fraction from server time", function()
		T.expect(GameModeVoteViewModel.progress(10, 20, 10)):toEqual(1)
		T.expect(GameModeVoteViewModel.progress(15, 20, 10)):toEqual(0.5)
		T.expect(GameModeVoteViewModel.progress(25, 20, 10)):toEqual(0)
		T.expect(GameModeVoteViewModel.progress(10, 20, 0)):toEqual(0)
	end)
end)

return true
