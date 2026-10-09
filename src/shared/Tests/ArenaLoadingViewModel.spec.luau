-- Description: Spec for the arena loading overlay decisions: roster-wait detection and copy, Delayed return copy, party-wait actions, and the rejected-admission RETURN.

--!strict

local T = require(script.Parent.TestKit)
local ArenaLoadingViewModel = require(script.Parent.Parent.UI.Models.ArenaLoadingViewModel)

local function loadingState(overrides: { [string]: any }?): any
	local state: { [string]: any } = {
		admission = "Matched",
		localReady = true,
		gateReleased = true,
		matchPhase = "Idle",
		fixedModeId = nil,
		preloadReady = true,
		simulationReady = true,
		arrivedPlayerCount = 1,
		expectedPlayerCount = 2,
		readyPlayerCount = 1,
	}
	for key, value in overrides or {} do
		state[key] = value
	end
	return state
end

local closedVote = { open = false }

T.describe("ArenaLoadingViewModel", function()
	T.it("detects a ready player idling with no ballot and no round on the way", function()
		T.expect(ArenaLoadingViewModel.isWaitingForRoster(loadingState(), closedVote, nil)):toBeTruthy()
		T.expect(ArenaLoadingViewModel.isWaitingForRoster(loadingState(), { open = true }, nil)):toBeFalsy()
		T.expect(ArenaLoadingViewModel.isWaitingForRoster(loadingState({ matchPhase = "Results" }), closedVote, nil))
			:toBeFalsy()
		T.expect(ArenaLoadingViewModel.isWaitingForRoster(loadingState({ gateReleased = false }), closedVote, nil))
			:toBeFalsy()
		T.expect(
			ArenaLoadingViewModel.isWaitingForRoster(loadingState({ fixedModeId = "Splashdown" }), closedVote, nil)
		)
			:toBeFalsy()
		T.expect(ArenaLoadingViewModel.isWaitingForRoster(loadingState({ admission = "Rejected" }), closedVote, nil))
			:toBeFalsy()
		T.expect(ArenaLoadingViewModel.isWaitingForRoster(loadingState(), closedVote, { state = "Attempting" }))
			:toBeFalsy()
	end)

	T.it("keeps JOINING MATCH briefly, then offers RETURN with a waiting-for-players state", function()
		local title, detail = ArenaLoadingViewModel.copy(loadingState(), closedVote, nil, false, false)
		T.expect(title):toEqual("JOINING MATCH")
		T.expect(detail):toBeNil()
		local primary = ArenaLoadingViewModel.actions(loadingState(), nil, false)
		T.expect(primary):toBeNil()

		title, detail = ArenaLoadingViewModel.copy(loadingState(), closedVote, nil, false, true)
		T.expect(title):toEqual("WAITING FOR PLAYERS")
		T.expect(detail):toEqual("NOT ENOUGH PLAYERS TO START")
		primary = ArenaLoadingViewModel.actions(loadingState(), nil, true)
		T.expect(primary):toEqual("Return")
	end)

	T.it("shows the lobby-return title for a Delayed teleport instead of ballot copy", function()
		local title, detail = ArenaLoadingViewModel.copy(
			loadingState(),
			{ open = true },
			{ state = "Delayed" },
			false,
			false
		)
		T.expect(title):toEqual("RETURNING TO LOBBY")
		T.expect(detail):toEqual("THIS IS TAKING LONGER THAN USUAL")
		title = ArenaLoadingViewModel.copy(loadingState(), closedVote, { state = "Attempting" }, false, false)
		T.expect(title):toEqual("RETURNING TO LOBBY")
	end)

	T.it("offers TRY AGAIN and STAY only while the server honors them", function()
		local primary, secondary =
			ArenaLoadingViewModel.actions(loadingState(), { state = "Failed", canRetry = true, canStay = true }, false)
		T.expect(primary):toEqual("Retry")
		T.expect(secondary):toEqual("Stay")

		local waiting = { state = "Failed", canRetry = false, canStay = false, waitingForParty = true }
		primary, secondary = ArenaLoadingViewModel.actions(loadingState(), waiting, false)
		T.expect(primary):toBeNil()
		T.expect(secondary):toBeNil()
		local title = ArenaLoadingViewModel.copy(loadingState(), closedVote, waiting, false, false)
		T.expect(title):toEqual("WAITING FOR YOUR PARTY")

		-- Older packets without the flags keep both buttons.
		primary, secondary = ArenaLoadingViewModel.actions(loadingState(), { state = "Failed" }, false)
		T.expect(primary):toEqual("Retry")
		T.expect(secondary):toEqual("Stay")
	end)

	T.it("keeps RETURN on a rejected admission", function()
		local rejected = loadingState({ admission = "Rejected", localReady = false })
		T.expect(ArenaLoadingViewModel.actions(rejected, nil, false)):toEqual("Return")
		local title = ArenaLoadingViewModel.copy(rejected, closedVote, nil, false, false)
		T.expect(title):toEqual("UNABLE TO JOIN MATCH")
	end)

	T.it("does not repeat the loading title as its detail line", function()
		local loading = loadingState({ localReady = false, preloadReady = false, simulationReady = false })
		local title, detail = ArenaLoadingViewModel.copy(loading, closedVote, nil, false, false)
		T.expect(title):toEqual("LOADING ARENA")
		T.expect(detail):toBeNil()
	end)
end)

return true
