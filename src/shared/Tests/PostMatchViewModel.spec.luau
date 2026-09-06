-- Name: PostMatchViewModel.spec.luau
-- Author: Jack C.
-- Description: Spec for post-match action permissions, explicit self-separation copy, countdown rounding, and bounded responsive canvas sizing.
-- Created: 2026-08-31

--!strict

local T = require(script.Parent.TestKit)
local PostMatchViewModel = require(script.Parent.Parent.UI.Models.PostMatchViewModel)

local function party(localUserId: number)
	return {
		leaderUserId = 10,
		members = {
			{ userId = 10, displayName = "Leader", isLocal = localUserId == 10 },
			{ userId = 20, displayName = "Member", isLocal = localUserId == 20 },
		},
	}
end

T.describe("PostMatchViewModel", function()
	T.it("offers population recovery even after replay was selected", function()
		local model = PostMatchViewModel.actions(10, party(10), { state = "PlayAgain", canReplay = false }, false, nil)
		T.expect(model.primaryText):toEqual("FIND PLAYERS")
		T.expect(model.primaryEnabled):toEqual(true)
		local staying = PostMatchViewModel.actions(10, party(10), { state = "PlayAgain", canReplay = true }, false, nil)
		T.expect(staying.primaryText):toEqual("NEXT ROUND ✓")
		T.expect(staying.primaryEnabled):toEqual(false)
	end)
	T.it("explains the explicit queue handoff without implying a purchase or solo match", function()
		local model = PostMatchViewModel.actions(10, nil, { state = "Returning", findingPlayers = true }, false, nil)
		T.expect(model.statusText):toEqual("HEADING TO THE LOBBY TO FIND PLAYERS")
		T.expect(model.busy):toEqual(true)
	end)
	T.it("names the server-projected destination without guessing for older packets", function()
		T.expect(PostMatchViewModel.destination(nil, 1)):toBeNil()
		T.expect(PostMatchViewModel.destination({ state = "Interactive" }, 4)):toBeNil()
		T.expect(PostMatchViewModel.destination({ nextDestination = "Arena" }, 1))
			:toEqual("NEXT ROUND WHEN THE TIMER ENDS")
		T.expect(PostMatchViewModel.destination({ nextDestination = "Lobby" }, 4))
			:toEqual("YOUR PARTY RETURNS TO LOBBY WHEN THE TIMER ENDS")
		T.expect(PostMatchViewModel.destination({ nextDestination = "Lobby", selfReturning = true }, 4))
			:toEqual("RETURNING TO LOBBY WHEN THE TIMER ENDS")
	end)
	T.it("keeps every party-wide action with the leader", function()
		local model =
			PostMatchViewModel.actions(10, party(10), { leaderUserId = 10, state = "Interactive" }, false, nil)
		T.expect(model.isLeader):toBeTruthy()
		T.expect(model.primaryText):toEqual("PLAY AGAIN WITH PARTY")
		T.expect(model.returnAction):toEqual("ReturnToLobby")
		T.expect(model.returnText):toEqual("RETURN PARTY TO LOBBY")
	end)

	T.it("gives a non-leader an explicit self-only separation action", function()
		local model =
			PostMatchViewModel.actions(20, party(20), { leaderUserId = 10, state = "Interactive" }, false, nil)
		T.expect(model.isLeader):toEqual(false)
		T.expect(model.primaryText):toEqual("WAITING FOR LEADER")
		T.expect(model.returnAction):toEqual("LeaveParty")
		T.expect(model.returnText):toEqual("LEAVE PARTY & RETURN")
		T.expect(string.find(model.statusText, "WITHOUT MOVING THE PARTY", 1, true) ~= nil):toBeTruthy()
	end)

	T.it("treats absent optional party data as a controllable solo result", function()
		local model = PostMatchViewModel.actions(20, nil, nil, false, nil)
		T.expect(model.isLeader):toBeTruthy()
		T.expect(model.returnAction):toEqual("ReturnToLobby")
	end)

	T.it("states that an in-flight separation returns only the local member", function()
		local model =
			PostMatchViewModel.actions(20, party(20), { leaderUserId = 10, state = "Interactive" }, true, "LeaveParty")
		T.expect(model.busy):toBeTruthy()
		T.expect(model.statusText):toEqual("LEAVING PARTY - RETURNING ONLY YOU")
	end)

	T.it("rounds the authoritative expiry up and clamps it at zero", function()
		T.expect(PostMatchViewModel.remainingSeconds(20, 12.2)):toEqual(8)
		T.expect(PostMatchViewModel.remainingSeconds(20, 21)):toEqual(0)
	end)

	T.it("bounds TV canvases and avoids portrait-height stretching", function()
		local wideWidth, wideHeight, wideCompact = PostMatchViewModel.canvasSize(3840, 2160)
		T.expect(wideWidth):toEqual(1920)
		T.expect(wideHeight):toEqual(1080)
		T.expect(wideCompact):toEqual(false)
		local portraitWidth, portraitHeight, portraitCompact = PostMatchViewModel.canvasSize(768, 1024)
		T.expect(portraitWidth):toEqual(768)
		T.expect(portraitHeight):toEqual(576)
		T.expect(portraitCompact):toBeTruthy()
	end)
end)

return true
