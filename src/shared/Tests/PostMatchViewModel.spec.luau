-- Description: Spec for post-match action permissions and copy, explicit self-separation, countdown captions, stage headings, stat formatting, the season bar reveal, and countdown rounding.

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
		T.expect(model.primaryStyle):toEqual("Primary")
		local staying = PostMatchViewModel.actions(10, party(10), { state = "PlayAgain", canReplay = true }, false, nil)
		T.expect(staying.primaryText):toEqual("NEXT ROUND ✓")
		T.expect(staying.primaryStyle):toEqual("Done")
		T.expect(staying.primaryEnabled):toEqual(false)
		T.expect(staying.statusText):toEqual("YOUR PARTY STAYS FOR THE NEXT ROUND")
	end)

	T.it("explains the explicit queue handoff without implying a purchase or solo match", function()
		local model = PostMatchViewModel.actions(10, nil, { state = "Returning", findingPlayers = true }, false, nil)
		T.expect(model.statusText):toEqual("HEADING TO THE LOBBY TO FIND PLAYERS")
		T.expect(model.busy):toEqual(true)
		T.expect(model.primaryText):toEqual("PLEASE WAIT…")
	end)

	T.it("captions the countdown from the server-projected destination", function()
		T.expect(PostMatchViewModel.countdown(nil, 1, 8).caption):toEqual("RESULTS END IN")
		T.expect(PostMatchViewModel.countdown({ state = "Interactive" }, 4, 8).caption):toEqual("RESULTS END IN")
		T.expect(PostMatchViewModel.countdown({ nextDestination = "Arena" }, 1, 8).caption):toEqual("NEXT ROUND IN")
		T.expect(PostMatchViewModel.countdown({ nextDestination = "Lobby" }, 4, 8).caption):toEqual("PARTY LEAVES IN")
		T.expect(PostMatchViewModel.countdown({ nextDestination = "Lobby", selfReturning = true }, 4, 8).caption)
			:toEqual("LOBBY IN")
		T.expect(PostMatchViewModel.countdown({ nextDestination = "Lobby" }, 1, 8).value):toEqual("8s")
		local departing = PostMatchViewModel.countdown({ nextDestination = "Lobby" }, 1, 0, true)
		T.expect(departing.caption):toEqual("HEADING TO")
		T.expect(departing.value):toEqual("LOBBY")
	end)

	T.it("keeps every party-wide action with the leader", function()
		local model =
			PostMatchViewModel.actions(10, party(10), { leaderUserId = 10, state = "Interactive" }, false, nil)
		T.expect(model.isLeader):toBeTruthy()
		T.expect(model.primaryText):toEqual("PLAY AGAIN")
		T.expect(model.primaryEnabled):toBeTruthy()
		T.expect(model.returnAction):toEqual("ReturnToLobby")
		T.expect(model.returnText):toEqual("LOBBY")
		T.expect(model.statusText):toEqual("READY FOR ANOTHER ROUND?")
	end)

	T.it("gives a non-leader an explicit self-only separation action", function()
		local model =
			PostMatchViewModel.actions(20, party(20), { leaderUserId = 10, state = "Interactive" }, false, nil)
		T.expect(model.isLeader):toEqual(false)
		T.expect(model.primaryText):toEqual("LEADER DECIDES")
		T.expect(model.primaryStyle):toEqual("Waiting")
		T.expect(model.primaryEnabled):toEqual(false)
		T.expect(model.returnAction):toEqual("LeaveParty")
		T.expect(model.returnText):toEqual("LEAVE PARTY")
		T.expect(model.leaderName):toEqual("LEADER")
		T.expect(string.find(model.statusText, "LEAVE PARTY TO GO ALONE", 1, true) ~= nil):toBeTruthy()
		T.expect(string.find(model.statusText, "LEADER", 1, true) ~= nil):toBeTruthy()
	end)

	T.it("treats absent optional party data as a controllable solo result", function()
		local model = PostMatchViewModel.actions(20, nil, nil, false, nil)
		T.expect(model.isLeader):toBeTruthy()
		T.expect(model.returnAction):toEqual("ReturnToLobby")
		T.expect(model.partySize):toEqual(1)
	end)

	T.it("states that an in-flight separation returns only the local member", function()
		local model =
			PostMatchViewModel.actions(20, party(20), { leaderUserId = 10, state = "Interactive" }, true, "LeaveParty")
		T.expect(model.busy):toBeTruthy()
		T.expect(model.statusText):toEqual("LEAVING YOUR PARTY · HEADING TO THE LOBBY")
	end)

	T.it("holds the screen in a busy departing state once the lobby trip has begun", function()
		local model = PostMatchViewModel.actions(
			10,
			party(10),
			{ state = "Interactive", nextDestination = "Lobby" },
			false,
			nil,
			true
		)
		T.expect(model.busy):toBeTruthy()
		T.expect(model.primaryEnabled):toBeFalsy()
		T.expect(model.statusText):toEqual("YOUR PARTY IS HEADING TO THE LOBBY")
		local alone = PostMatchViewModel.actions(20, party(20), { selfReturning = true }, false, nil, true)
		T.expect(alone.statusText):toEqual("LEAVING YOUR PARTY · HEADING TO THE LOBBY")
	end)

	T.it("names the mode and outcome in one kicker line", function()
		T.expect(PostMatchViewModel.kicker("Splashdown", "MATCH COMPLETE")):toEqual("SPLASHDOWN · MATCH COMPLETE")
	end)

	T.it("labels the stage from the podium contents", function()
		T.expect(PostMatchViewModel.stageHeading(false, 3, false, false)):toEqual("TOP FINISHERS")
		T.expect(PostMatchViewModel.stageHeading(true, 3, false, false)):toEqual("WINNING TEAM STANDOUTS")
		T.expect(PostMatchViewModel.stageHeading(true, 0, true, false)):toEqual("DEAD HEAT")
		T.expect(PostMatchViewModel.stageHeading(false, 0, false, false)):toEqual("READY FOR THE NEXT ONE")
		T.expect(PostMatchViewModel.stageHeading(false, 3, false, true)):toEqual("FINAL STANDINGS")
	end)

	T.it("formats race times and placements while grouping plain counts", function()
		T.expect(PostMatchViewModel.statText({ id = "TotalTime", value = 94.3 })):toEqual("1:34.3")
		T.expect(PostMatchViewModel.statText({ id = "BestFinish", value = 2 })):toEqual("2ND")
		T.expect(PostMatchViewModel.statText({ id = "BestFinish", value = 0 })):toEqual("—")
		T.expect(PostMatchViewModel.statText({ id = "Placement", value = 11 })):toEqual("11TH")
		T.expect(PostMatchViewModel.statText({ id = "Eliminations", value = 1200 })):toEqual("1,200")
	end)

	T.it("animates the season bar from the pre-match position and flags a tier up", function()
		local steady = PostMatchViewModel.seasonReveal({
			beforeXp = 3200,
			afterXp = 3230,
			beforeTier = 16,
			afterTier = 16,
			xpIntoTier = 50,
			xpForNextTier = 1000,
		})
		T.expect(steady.tierUp):toBeFalsy()
		T.expect(steady.startFraction):toEqual(0.02)
		T.expect(steady.endFraction):toEqual(0.05)
		local promoted = PostMatchViewModel.seasonReveal({
			beforeXp = 3200,
			afterXp = 4050,
			beforeTier = 16,
			afterTier = 17,
			xpIntoTier = 50,
			xpForNextTier = 1000,
		})
		T.expect(promoted.tierUp):toBeTruthy()
		T.expect(promoted.startFraction):toEqual(0)
		T.expect(promoted.endFraction):toEqual(0.05)
	end)

	T.it("rounds the authoritative expiry up and clamps it at zero", function()
		T.expect(PostMatchViewModel.remainingSeconds(20, 12.2)):toEqual(8)
		T.expect(PostMatchViewModel.remainingSeconds(20, 21)):toEqual(0)
	end)
end)

return true
