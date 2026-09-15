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
		local leader = LobbyViewModel.partyPresentation(
			{ leaderUserId = 1, phase = "Lobby", queueId = "Arena" },
			1,
			false,
			"Arena"
		)
		local member = LobbyViewModel.partyPresentation({ leaderUserId = 1, phase = "Lobby" }, 2, false)
		T.expect(leader.playEnabled):toEqual(true)
		T.expect(member.partyState):toEqual("WAITING FOR PARTY LEADER")
		T.expect(member.playEnabled):toEqual(false)
	end)

	T.it("starts unselected despite an authoritative default queue", function()
		local snapshot = { partyId = "party-a", leaderUserId = 1, phase = "Lobby", queueId = "Arena" }
		local selected = LobbyViewModel.selectedQueueId(snapshot, 1, nil)
		local state = LobbyViewModel.partyPresentation(snapshot, 1, false, selected)
		T.expect(selected):toEqual(nil)
		T.expect(state.playEnabled):toEqual(false)
		T.expect(state.canPickQueue):toEqual(true)
		T.expect(state.partyState):toEqual("SELECT A GAME MODE")
	end)

	T.it("unlocks Play after an explicit choice of either queue including the internal default", function()
		for _, queueId in { "Arena", "Splashdown" } do
			local snapshot = { partyId = "party-a", leaderUserId = 1, phase = "Lobby", queueId = queueId }
			local choice = { partyId = "party-a", leaderUserId = 1, queueId = queueId }
			local selected = LobbyViewModel.selectedQueueId(snapshot, 1, choice)
			T.expect(selected):toEqual(queueId)
			T.expect(LobbyViewModel.partyPresentation(snapshot, 1, false, selected).playEnabled):toEqual(true)
			T.expect(LobbyViewModel.partyPresentation(snapshot, 1, true, selected).playEnabled):toEqual(false)
		end
	end)

	T.it("does not unlock for an unaccepted queue, another party, or a previous leader", function()
		local snapshot = { partyId = "party-a", leaderUserId = 1, phase = "Lobby", queueId = "Arena" }
		for _, choice in
			{
				{ partyId = "party-a", leaderUserId = 1, queueId = "Splashdown" },
				{ partyId = "party-b", leaderUserId = 1, queueId = "Arena" },
				{ partyId = "party-a", leaderUserId = 2, queueId = "Arena" },
			}
		do
			local selected = LobbyViewModel.selectedQueueId(snapshot, 1, choice)
			T.expect(selected):toEqual(nil)
			T.expect(LobbyViewModel.partyPresentation(snapshot, 1, false, selected).playEnabled):toEqual(false)
		end
		T.expect(LobbyViewModel.selectedQueueId(nil, 1, nil)):toEqual(nil)
		T.expect(LobbyViewModel.partyPresentation(nil, 1, false).playEnabled):toEqual(false)
	end)

	T.it("keeps members read-only and shows the party's queue", function()
		local snapshot = { partyId = "party-a", leaderUserId = 2, phase = "Lobby", queueId = "Splashdown" }
		local selected = LobbyViewModel.selectedQueueId(snapshot, 1, nil)
		local state = LobbyViewModel.partyPresentation(snapshot, 1, false, selected)
		T.expect(selected):toEqual("Splashdown")
		T.expect(state.playEnabled):toEqual(false)
		T.expect(state.canPickQueue):toEqual(false)
	end)

	T.it("keeps Cancel available without a local choice when queued or returning", function()
		for _, snapshot in
			{
				{ partyId = "party-a", leaderUserId = 1, phase = "Queued", queueId = "Splashdown" },
				{
					partyId = "party-a",
					leaderUserId = 1,
					phase = "Lobby",
					queueId = "Splashdown",
					returnQueuePending = true,
				},
			}
		do
			T.expect(LobbyViewModel.selectedQueueId(snapshot, 1, nil)):toEqual("Splashdown")
			local state = LobbyViewModel.partyPresentation(snapshot, 1, false)
			T.expect(state.playText):toEqual("CANCEL")
			T.expect(state.playEnabled):toEqual(true)
			T.expect(LobbyViewModel.partyPresentation(snapshot, 1, true).playEnabled):toEqual(false)
		end
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
		T.expect(teleporting.partyState):toEqual("HEADING TO THE MATCH")
		T.expect(teleporting.showMatchmakingActivity):toEqual(false)
	end)

	T.it("lets only an idle party leader change the queue", function()
		local function canPick(snapshot, userId, busy)
			return LobbyViewModel.partyPresentation(snapshot, userId, busy).canPickQueue
		end
		T.expect(canPick({ leaderUserId = 1, phase = "Lobby" }, 1, false)):toEqual(true)
		T.expect(canPick({ leaderUserId = 1, phase = "Lobby" }, 1, true)):toEqual(false)
		T.expect(canPick({ leaderUserId = 1, phase = "Lobby" }, 2, false)):toEqual(false)
		T.expect(canPick({ leaderUserId = 1, phase = "Queued" }, 1, false)):toEqual(false)
		T.expect(canPick({ leaderUserId = 1, phase = "Lobby", returnQueuePending = true }, 1, false)):toEqual(false)
		T.expect(canPick(nil, 1, false)):toEqual(false)
	end)
end)

return true
