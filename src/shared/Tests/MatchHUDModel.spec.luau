--!strict

local T = require(script.Parent.TestKit)
local Model = require(script.Parent.Parent.UI.Models.MatchHUDModel)

T.describe("MatchHUDModel", function()
	T.it("shows the opponent recovery deadline without a spawn shield banner", function()
		T.expect(Model.build({ spawnProtected = true }, 100).respawn):toBeNil()
		T.expect(Model.build({ opponentDeadline = 108, spawnProtected = true }, 101).respawn)
			:toEqual("WAITING FOR OPPONENTS • 7s")
	end)
	T.it("identifies only living allies and never the local player or unassigned players", function()
		T.expect(Model.isTeammate({ teamId = "Blue", alive = true }, "Blue")):toBeTruthy()
		T.expect(Model.isTeammate({ teamId = "Red", alive = true }, "Blue")):toEqual(false)
		T.expect(Model.isTeammate({ teamId = "Blue", alive = false }, "Blue")):toEqual(false)
		T.expect(Model.isTeammate({ teamId = "Blue", alive = true, isLocal = true }, "Blue")):toEqual(false)
		T.expect(Model.isTeammate({ alive = true }, nil)):toEqual(false)
	end)
	T.it("does not stack the spawn shield banner under the starting countdown", function()
		local view = Model.build({ phase = "Starting", spawnProtected = true, timeRemaining = 3 }, 0)
		T.expect(view.starting):toEqual(true)
		T.expect(view.respawn):toBeNil()
	end)
	T.it("uses the server's starting countdown and mode objective", function()
		local view = Model.build({ phase = "Starting", timeRemaining = 3, scoreTarget = 40 }, 0)
		T.expect(view.starting):toBeTruthy()
		T.expect(view.remaining):toEqual(3)
		T.expect(view.objective):toEqual("FIRST TO 40 ELIMINATIONS")
		T.expect(Model.build({ phase = "Active" }, 0).starting):toEqual(false)
		T.expect(view.active):toEqual(false)
		T.expect(Model.build({ phase = "Active" }, 0).active):toEqual(true)
	end)
	T.it("orders live standings without inventing tie breakers or mutating player facts", function()
		local players = {
			{ userId = 30, displayName = "THREE", score = 4, isLocal = true },
			{ userId = 10, displayName = "ONE", score = 4 },
			{ userId = 20, displayName = "TWO", score = 8 },
		}
		local view = Model.build({ players = players, scoreboardOpen = true }, 0)
		T.expect(view.entries[1].userId):toEqual(20)
		T.expect(view.entries[2].userId):toEqual(10)
		T.expect(view.entries[3].placement):toEqual(2)
		T.expect(view.placement):toEqual(2)
		T.expect(view.scoreboardOpen):toEqual(true)
		T.expect(players[1].placement):toBeNil()
	end)
	T.it("formats authoritative scores and the time cap", function()
		local view = Model.build({ timeRemaining = 125, scoreTarget = 15, score = 4 }, 0)
		T.expect(view.clock):toEqual("2:05")
		T.expect(view.objective):toEqual("FIRST TO 15 ELIMINATIONS")
		T.expect(view.scores):toEqual("YOUR ELIMINATIONS  4")
	end)
	T.it("derives wave respawns from the replicated deadline", function()
		T.expect(Model.build({ alive = false, respawnAt = 103 }, 100).respawn):toEqual("BACK IN 3…")
		T.expect(Model.build({ alive = false, respawnAt = 103 }, 104).respawn):toEqual("RESPAWNING…")
	end)
	T.it("identifies teams in text and explains round exclusion", function()
		local view = Model.build({
			teams = { { id = "Red", score = 7 }, { id = "Blue", score = 5 } },
			scoreTarget = 40,
			teamId = "Blue",
			eligible = false,
		}, 0)
		T.expect(view.scores):toEqual("RED 7   •   BLUE 5   |   YOU: BLUE")
		T.expect(view.respawn):toEqual("YOU’LL JOIN THE NEXT ROUND")
	end)
	T.it("names whatever sides the mode declares rather than Red and Blue", function()
		local view = Model.build({
			teams = { { id = "Survivors", score = 6 }, { id = "Infected", score = 3 } },
			scoreTarget = 0,
			teamId = "Survivors",
		}, 0)
		T.expect(view.scores):toEqual("SURVIVORS 6   •   INFECTED 3   |   YOU: SURVIVORS")
		T.expect(view.objective):toEqual("SURVIVE UNTIL TIME RUNS OUT")
		T.expect(view.footer):toEqual("ELIMINATIONS • PLAYERS LEFT ABOVE")
		-- Nothing to count up to, so the bars read against the total on the board.
		T.expect(view.teamScoreMax):toEqual(9)
		T.expect(view.teams[1].accent):toEqual("Pink")
		T.expect(view.teams[2].accent):toEqual("Cyan")
	end)
	T.it("never renders an infinite score target as the objective", function()
		local view = Model.build({ scoreTarget = math.huge }, 0)
		T.expect(view.objective):toEqual("SURVIVE UNTIL TIME RUNS OUT")
		T.expect(view.target):toEqual(0)
	end)
	T.it("defaults the score label to ELIMS for callers that predate labelled modes", function()
		local view = Model.build({ scoreTarget = 40, score = 4 }, 0)
		T.expect(view.scoreLabel):toEqual("ELIMS")
	end)
	T.it("carries a mode's own score label onto the view unchanged", function()
		local view = Model.build({ scoreLabel = "POINTS" }, 0)
		T.expect(view.scoreLabel):toEqual("POINTS")
	end)
	T.it("replaces the objective and footer with race copy for a non-combat mode", function()
		local view = Model.build({ combat = false, scoreLabel = "POINTS", scoreTarget = 0 }, 0)
		T.expect(view.objective):toEqual("RACE TO THE FINISH")
		T.expect(view.footer):toEqual("POINTS")
	end)
	T.it("keeps a non-combat objective even when a stray score target replicates", function()
		local view = Model.build({ combat = false, scoreLabel = "POINTS", scoreTarget = 40 }, 0)
		T.expect(view.objective):toEqual("RACE TO THE FINISH")
	end)
end)

T.describe("MatchHUDModel standings", function()
	local function players(scores: { number }, localIndex: number)
		local list = {}
		for index, score in scores do
			table.insert(
				list,
				{ userId = index, displayName = `P{index}`, score = score, isLocal = index == localIndex, alive = true }
			)
		end
		return Model.standings(list)
	end
	T.it("shows the top rows plus the local player when they sit below the cut", function()
		local rows = Model.strip(players({ 9, 7, 5, 3, 1 }, 5), 3)
		T.expect(#rows):toEqual(4)
		T.expect(rows[4].isLocal):toEqual(true)
		T.expect(rows[4].placement):toEqual(5)
	end)
	T.it("does not duplicate a local player already inside the cut", function()
		local rows = Model.strip(players({ 9, 7, 5, 3, 1 }, 2), 3)
		T.expect(#rows):toEqual(3)
		T.expect(rows[2].isLocal):toEqual(true)
	end)
	T.it("shows everyone when the match is smaller than the cut", function()
		T.expect(#Model.strip(players({ 2, 1 }, 1), 3)):toEqual(2)
	end)
	T.it("splits team boards by team and long free-for-alls in half", function()
		local entries = players({ 5, 4, 3, 2 }, 1)
		entries[1].teamId, entries[2].teamId, entries[3].teamId, entries[4].teamId = "Red", "Blue", "Red", "Blue"
		local teams = { { id = "Red" }, { id = "Blue" } }
		local columns = Model.columns(entries, teams, 8)
		T.expect(#columns):toEqual(2)
		T.expect(#columns[1]):toEqual(2)
		T.expect(columns[1][1].teamId):toEqual("Red")
		T.expect(#Model.columns(players({ 1, 1, 1 }, 1), nil, 8)):toEqual(1)
		local halves = Model.columns(players({ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 1), nil, 8)
		T.expect(#halves):toEqual(2)
		T.expect(#halves[1]):toEqual(5)
		T.expect(#halves[2]):toEqual(4)
	end)
end)

return true
