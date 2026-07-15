--!strict

local T = require(script.Parent.TestKit)
local MatchSim = require(script.Parent.Parent.Game.Sim.MatchSim)
local ModeRegistry = require(script.Parent.Parent.Game.Modes.ModeRegistry)

type MatchEvent = MatchSim.MatchEvent

local RULES = ModeRegistry.default().rules

local function activeMatch(playerIds: { string }): (MatchSim.MatchState, { MatchEvent })
	local state = MatchSim.newState()
	local present: { [string]: boolean } = {}
	for _, id in playerIds do
		present[id] = true
	end
	MatchSim.setPlayers(state, present)
	local events: { MatchEvent } = {}
	MatchSim.start(state, RULES, events)
	return state, events
end

local function lastEvent(events: { MatchEvent }, kind: string): MatchEvent?
	local found: MatchEvent? = nil
	for _, event in events do
		if event.kind == kind then
			found = event
		end
	end
	return found
end

T.describe("MatchSim", function()
	T.it("starts Active with reset scores and the full time cap", function()
		local state, events = activeMatch({ "p1", "p2" })
		T.expect(state.phase):toEqual("Active")
		T.expect(state.timeRemaining):toEqual(RULES.TimeCapSeconds)
		T.expect(state.scores.p1):toEqual(0)
		T.expect(lastEvent(events, "MatchStarted") ~= nil):toBeTruthy()
	end)

	T.it("scores one point per elimination", function()
		local state, _ = activeMatch({ "p1", "p2" })
		local events: { MatchEvent } = {}
		MatchSim.applyElim(state, RULES, "p1", "p2", events)
		T.expect(state.scores.p1):toEqual(1)
		local changed = lastEvent(events, "ScoreChanged")
		T.expect(changed ~= nil):toBeTruthy()
		T.expect((changed :: MatchEvent).playerId):toEqual("p1")
		T.expect((changed :: MatchEvent).score):toEqual(1)
	end)

	T.it("can score team ids for team modes", function()
		local state = MatchSim.newState()
		MatchSim.setPlayers(state, { Red = true, Blue = true })
		local events: { MatchEvent } = {}
		MatchSim.start(state, RULES, events)
		MatchSim.applyElim(state, RULES, "Red", "p2", events)
		T.expect(state.scores.Red):toEqual(1)
		local changed = lastEvent(events, "ScoreChanged")
		T.expect((changed :: MatchEvent).playerId):toEqual("Red")
	end)

	T.it("ignores self-eliminations, unknown sources, and inactive phases", function()
		local state, _ = activeMatch({ "p1", "p2" })
		local events: { MatchEvent } = {}
		MatchSim.applyElim(state, RULES, "p1", "p1", events)
		MatchSim.applyElim(state, RULES, nil, "p2", events)
		MatchSim.applyElim(state, RULES, "ghost", "p2", events)
		T.expect(#events):toEqual(0)
		T.expect(state.scores.p1):toEqual(0)

		state.phase = "Results"
		MatchSim.applyElim(state, RULES, "p1", "p2", events)
		T.expect(state.scores.p1):toEqual(0)
	end)

	T.it("ends the match at the score target with the scorer as winner", function()
		local state, _ = activeMatch({ "p1", "p2" })
		local events: { MatchEvent } = {}
		for _ = 1, RULES.ScoreTarget do
			MatchSim.applyElim(state, RULES, "p1", "p2", events)
		end
		T.expect(state.phase):toEqual("Results")
		local ended = lastEvent(events, "MatchEnded")
		T.expect((ended :: MatchEvent).winnerId):toEqual("p1")
		T.expect((ended :: MatchEvent).reason):toEqual("ScoreTarget")
	end)

	T.it("ends at the time cap with the leader as winner", function()
		local state, _ = activeMatch({ "p1", "p2" })
		local events: { MatchEvent } = {}
		MatchSim.applyElim(state, RULES, "p2", "p1", events)
		MatchSim.tick(state, RULES, RULES.TimeCapSeconds + 1, events)
		local ended = lastEvent(events, "MatchEnded")
		T.expect((ended :: MatchEvent).winnerId):toEqual("p2")
		T.expect((ended :: MatchEvent).reason):toEqual("TimeCap")
	end)

	T.it("declares no winner on a tie at the time cap", function()
		local state, _ = activeMatch({ "p1", "p2" })
		local events: { MatchEvent } = {}
		MatchSim.applyElim(state, RULES, "p1", "p2", events)
		MatchSim.applyElim(state, RULES, "p2", "p1", events)
		MatchSim.tick(state, RULES, RULES.TimeCapSeconds + 1, events)
		local ended = lastEvent(events, "MatchEnded")
		T.expect((ended :: MatchEvent).winnerId):toBeNil()
	end)

	T.it("passes through Intermission between Results and Idle", function()
		local state, _ = activeMatch({ "p1", "p2" })
		local events: { MatchEvent } = {}
		MatchSim.tick(state, RULES, RULES.TimeCapSeconds + 1, events)
		T.expect(state.phase):toEqual("Results")

		MatchSim.tick(state, RULES, RULES.ResultsSeconds + 1, events)
		T.expect(state.phase):toEqual("Intermission")
		T.expect(state.intermissionRemaining):toEqual(RULES.IntermissionSeconds)
		T.expect(lastEvent(events, "MatchReset") ~= nil):toBeTruthy()

		MatchSim.tick(state, RULES, RULES.IntermissionSeconds + 1, events)
		T.expect(state.phase):toEqual("Idle")
		T.expect(lastEvent(events, "IntermissionEnded") ~= nil):toBeTruthy()
	end)

	T.it("drops leavers' scores and admits joiners at zero mid-match", function()
		local state, _ = activeMatch({ "p1", "p2" })
		local events: { MatchEvent } = {}
		MatchSim.applyElim(state, RULES, "p1", "p2", events)
		MatchSim.setPlayers(state, { p2 = true, p3 = true })
		T.expect(state.scores.p1):toBeNil()
		T.expect(state.scores.p3):toEqual(0)
	end)
end)

T.describe("ModeRegistry", function()
	T.it("provides a default mode with complete rules", function()
		local mode = ModeRegistry.default()
		T.expect(mode.id):toEqual("FFA")
		T.expect(mode.rules.ScoreTarget > 0):toBeTruthy()
		T.expect(mode.rules.TimeCapSeconds > 0):toBeTruthy()
	end)

	T.it("registers every mode with the full hook surface", function()
		for _, mode in ModeRegistry.all() do
			T.expect(typeof(mode.onMatchStart)):toEqual("function")
			T.expect(typeof(mode.onPlayerSpawned)):toEqual("function")
			T.expect(typeof(mode.onElim)):toEqual("function")
			T.expect(typeof(mode.onMatchEnd)):toEqual("function")
			T.expect(typeof(mode.displayName)):toEqual("string")
		end
	end)

	T.it("resolves modes by id and rejects unknown ids", function()
		local default = ModeRegistry.default()
		T.expect((ModeRegistry.get(default.id) :: any).id):toEqual(default.id)
		T.expect((ModeRegistry.get("TDM") :: any).id):toEqual("TDM")
		T.expect(ModeRegistry.get("Nope")):toBeNil()
	end)
end)

return true
