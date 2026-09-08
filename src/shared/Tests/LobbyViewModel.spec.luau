-- Description: Spec for the lobby view model: party code sanitizing and formatting, and the leader, member, queued, and terminal presentation states.

--!strict

local T = require(script.Parent.TestKit)
local LobbyViewModel = require(script.Parent.Parent.UI.Models.LobbyViewModel)

T.describe("LobbyViewModel", function()
	T.it("shows a cancellable return regrouping state only to the party leader", function()
		local snapshot = { leaderUserId = 1, phase = "Lobby", returnQueuePending = true }
		local leader = LobbyViewModel.partyPresentation(snapshot, 1, false)
		T.expect(leader.partyState):toEqual("REGROUPING TO FIND PLAYERS")
		T.expect(leader.playText):toEqual("CANCEL")
		T.expect(leader.showMatchmakingActivity):toEqual(true)
		T.expect(LobbyViewModel.partyPresentation(snapshot, 2, false).playEnabled):toEqual(false)
	end)
	T.it("sanitizes and formats six-digit party codes", function()
		T.expect(LobbyViewModel.sanitizeCode("12a3-4567")):toEqual("123456")
		T.expect(LobbyViewModel.formatJoinCode("12a3-45")):toEqual("123-45")
		T.expect(LobbyViewModel.formatPartyCode("123456", true)):toEqual("PARTY CODE: 123-456")
		T.expect(LobbyViewModel.formatPartyCode("123456", false)):toEqual("PARTY CODE: XXX-XXX")
	end)

	T.it("derives leader and member lobby actions", function()
		local leader = LobbyViewModel.partyPresentation({ leaderUserId = 1, phase = "Lobby" }, 1, false)
		local member = LobbyViewModel.partyPresentation({ leaderUserId = 1, phase = "Lobby" }, 2, false)
		T.expect(leader.partyState):toEqual("READY TO BRAWL?")
		T.expect(leader.playEnabled):toEqual(true)
		T.expect(member.partyState):toEqual("WAITING FOR PARTY LEADER")
		T.expect(member.playEnabled):toEqual(false)
	end)

	T.it("derives queued and terminal states", function()
		local queued = LobbyViewModel.partyPresentation({ leaderUserId = 1, phase = "Queued" }, 1, false)
		local claimed = LobbyViewModel.partyPresentation({ leaderUserId = 1, phase = "Claimed" }, 1, false)
		local assigned = LobbyViewModel.partyPresentation({ leaderUserId = 1, phase = "Assigned" }, 1, false)
		local teleporting = LobbyViewModel.partyPresentation({ leaderUserId = 1, phase = "Teleporting" }, 1, false)
		T.expect(queued.playText):toEqual("CANCEL")
		T.expect(queued.playEnabled):toEqual(true)
		T.expect(queued.showMatchmakingActivity):toEqual(true)
		T.expect(claimed.partyState):toEqual("ROUND COMING UP")
		T.expect(claimed.showMatchmakingActivity):toEqual(true)
		T.expect(assigned.partyState):toEqual("MATCH FOUND!")
		T.expect(assigned.showMatchmakingActivity):toEqual(false)
		T.expect(teleporting.partyState):toEqual("HEADING TO THE ARENA")
		T.expect(teleporting.showMatchmakingActivity):toEqual(false)
	end)
end)

return true
