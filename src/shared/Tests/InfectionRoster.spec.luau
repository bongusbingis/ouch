-- Description: Spec for the match-flow fixes around Infection and shared config: a side emptying by players leaving, the headcount score label, the Arena queue copy, and a never-scoring player not winning the leader fallback.

--!strict

local T = require(script.Parent.TestKit)
local Infection = require(script.Parent.Parent.Game.Modes.Infection)
local MatchSim = require(script.Parent.Parent.Game.Modes.MatchSim)
local GameModes = require(script.Parent.Parent.Parent.Config.Gameplay.GameModes)
local Queues = require(script.Parent.Parent.Parent.Config.Gameplay.Queues)

type Harness = {
	ctx: any,
	teams: { [string]: string? },
	finished: { { winnerId: string?, reason: string } },
}

local function harness(teamsByName: { [string]: string? }, order: { string }): Harness
	local teams = table.clone(teamsByName)
	local players = {}
	for _, name in order do
		table.insert(players, { Name = name })
	end
	local finished = {}
	local ctx = {
		balls = {
			grantHeldBall = function()
				return true
			end,
			clearAll = function() end,
		},
		getPlayers = function()
			return players
		end,
		getPlayerTeam = function(player: any)
			return teams[player.Name]
		end,
		getPlayerById = function()
			return nil
		end,
		setPlayerTeam = function(player: any, teamId: string?)
			teams[player.Name] = teamId
		end,
		finishMatch = function(winnerId: string?, reason: string)
			table.insert(finished, { winnerId = winnerId, reason = reason })
		end,
	}
	return { ctx = ctx, teams = teams, finished = finished }
end

local first = function()
	return 1
end

T.describe("Infection roster repair", function()
	T.it("ends the match for the infected when the last survivor leaves", function()
		local h = harness({ a = "Infected", b = "Infected" }, { "a", "b" })
		Infection.repairRoster(h.ctx, first)
		T.expect(#h.finished):toEqual(1)
		T.expect(h.finished[1].winnerId):toEqual(Infection.InfectedTeam)
		T.expect(h.finished[1].reason):toEqual("Infected")
	end)

	T.it("promotes a survivor when patient zero leaves and survivors remain", function()
		local h = harness({ a = "Survivors", b = "Survivors", c = "Survivors" }, { "a", "b", "c" })
		Infection.repairRoster(h.ctx, function(count)
			T.expect(count):toEqual(3)
			return 2
		end)
		T.expect(h.teams.b):toEqual("Infected")
		T.expect(h.teams.a):toEqual("Survivors")
		T.expect(h.teams.c):toEqual("Survivors")
		T.expect(#h.finished):toEqual(0)
	end)

	T.it("leaves a healthy round alone", function()
		local h = harness({ a = "Survivors", b = "Infected", c = "Survivors" }, { "a", "b", "c" })
		Infection.repairRoster(h.ctx, first)
		T.expect(#h.finished):toEqual(0)
		T.expect(h.teams.a):toEqual("Survivors")
		T.expect(h.teams.b):toEqual("Infected")
	end)

	T.it("does not end or infect when too few players remain to play", function()
		local lone = harness({ a = "Survivors" }, { "a" })
		Infection.repairRoster(lone.ctx, first)
		T.expect(lone.teams.a):toEqual("Survivors")
		T.expect(#lone.finished):toEqual(0)

		local aloneInfected = harness({ a = "Infected" }, { "a" })
		Infection.repairRoster(aloneInfected.ctx, first)
		T.expect(#aloneInfected.finished):toEqual(0)
	end)

	T.it("ignores players that have no side yet", function()
		local h = harness({ a = "Infected" }, { "a", "b" })
		Infection.repairRoster(h.ctx, first)
		T.expect(#h.finished):toEqual(1)
	end)
end)

T.describe("Infection labels and queue copy", function()
	T.it("labels the headcount score as players rather than eliminations", function()
		T.expect(GameModes.ScoreLabel("Infection")):toEqual("PLAYERS")
		T.expect(#GameModes.ScoreLabel("Infection") <= 16):toBeTruthy()
		T.expect(GameModes.ScoreLabel("FFA")):toEqual("ELIMS")
	end)

	T.it("mentions Infection and the map vote in the Arena queue description", function()
		local description = Queues.Queues.Arena.Description
		T.expect(string.find(description, "Infection", 1, true) ~= nil):toBeTruthy()
		T.expect(string.find(description, "map", 1, true) ~= nil):toBeTruthy()
	end)
end)

local RULES = {
	MinPlayers = 1,
	ScoreTarget = 10,
	TimeCapSeconds = 60,
	ResultsSeconds = 5,
	IntermissionSeconds = 5,
	StartingSeconds = 1,
	RespawnSeconds = 1,
	SpawnInvulnSeconds = 0,
	TimeCapWinnerId = nil,
	PreserveDodgeballs = false,
}

local function activeState(scores: { [string]: number }): MatchSim.MatchState
	local present = {}
	for id in scores do
		present[id] = true
	end
	local state = MatchSim.newState()
	MatchSim.setPlayers(state, present)
	local events = {}
	MatchSim.start(state, RULES, events)
	MatchSim.tick(state, RULES, RULES.StartingSeconds, events)
	for id, score in scores do
		state.scores[id] = score
	end
	return state
end

T.describe("MatchSim leader fallback", function()
	T.it("gives a lone player who never scored no win", function()
		local state = activeState({ p1 = 0 })
		MatchSim.finish(state, RULES, "RoundsComplete", {}, nil)
		T.expect(state.winnerId):toBeNil()
	end)

	T.it("still gives a lone player who scored the win", function()
		local state = activeState({ p1 = 2 })
		MatchSim.finish(state, RULES, "RoundsComplete", {}, nil)
		T.expect(state.winnerId):toEqual("p1")
	end)

	T.it("keeps ties at zero and at the top as no winner, and an unambiguous leader as the winner", function()
		local zeros = activeState({ p1 = 0, p2 = 0 })
		MatchSim.finish(zeros, RULES, "TimeCap", {}, nil)
		T.expect(zeros.winnerId):toBeNil()

		local tied = activeState({ p1 = 3, p2 = 3, p3 = 1 })
		MatchSim.finish(tied, RULES, "TimeCap", {}, nil)
		T.expect(tied.winnerId):toBeNil()

		local clear = activeState({ p1 = 3, p2 = 0, p3 = 1 })
		MatchSim.finish(clear, RULES, "TimeCap", {}, nil)
		T.expect(clear.winnerId):toEqual("p1")
	end)

	T.it("honours an explicit winner even at zero", function()
		local state = activeState({ Survivors = 0, Infected = 0 })
		MatchSim.finish(state, RULES, "Infected", {}, "Infected")
		T.expect(state.winnerId):toEqual("Infected")
	end)
end)

return true
