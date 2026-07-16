--!nonstrict
-- Cloud port of the MatchSim spec: pure match phase machine (Idle → Active →
-- Results → Intermission), scoring rules, and the ModeRegistry surface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")

local MatchSim = require(Game:WaitForChild("Sim"):WaitForChild("MatchSim"))
local ModeRegistry = require(Game:WaitForChild("Modes"):WaitForChild("ModeRegistry"))

local RULES = ModeRegistry.default().rules

local function activeMatch(playerIds)
	local state = MatchSim.newState()
	local present = {}
	for _, id in playerIds do
		present[id] = true
	end
	MatchSim.setPlayers(state, present)
	local events = {}
	MatchSim.start(state, RULES, events)
	return state, events
end

local function lastEvent(events, kind)
	local found = nil
	for _, event in events do
		if event.kind == kind then
			found = event
		end
	end
	return found
end

return function()
	describe("MatchSim", function()
		it("starts Active with reset scores and the full time cap", function()
			local state, events = activeMatch({ "p1", "p2" })
			expect(state.phase).to.equal("Active")
			expect(state.timeRemaining).to.equal(RULES.TimeCapSeconds)
			expect(state.scores.p1).to.equal(0)
			expect(lastEvent(events, "MatchStarted")).to.be.ok()
		end)

		it("scores one point per elimination", function()
			local state, _ = activeMatch({ "p1", "p2" })
			local events = {}
			MatchSim.applyElim(state, RULES, "p1", "p2", events)
			expect(state.scores.p1).to.equal(1)
			local changed = lastEvent(events, "ScoreChanged")
			expect(changed).to.be.ok()
			expect(changed.playerId).to.equal("p1")
			expect(changed.score).to.equal(1)
		end)

		it("can score team ids for team modes", function()
			local state = MatchSim.newState()
			MatchSim.setPlayers(state, { Red = true, Blue = true })
			local events = {}
			MatchSim.start(state, RULES, events)
			MatchSim.applyElim(state, RULES, "Red", "p2", events)
			expect(state.scores.Red).to.equal(1)
			local changed = lastEvent(events, "ScoreChanged")
			expect(changed.playerId).to.equal("Red")
		end)

		it("ignores self-eliminations, unknown sources, and inactive phases", function()
			local state, _ = activeMatch({ "p1", "p2" })
			local events = {}
			MatchSim.applyElim(state, RULES, "p1", "p1", events)
			MatchSim.applyElim(state, RULES, nil, "p2", events)
			MatchSim.applyElim(state, RULES, "ghost", "p2", events)
			expect(#events).to.equal(0)
			expect(state.scores.p1).to.equal(0)

			state.phase = "Results"
			MatchSim.applyElim(state, RULES, "p1", "p2", events)
			expect(state.scores.p1).to.equal(0)
		end)

		it("ends the match at the score target with the scorer as winner", function()
			local state, _ = activeMatch({ "p1", "p2" })
			local events = {}
			for _ = 1, RULES.ScoreTarget do
				MatchSim.applyElim(state, RULES, "p1", "p2", events)
			end
			expect(state.phase).to.equal("Results")
			local ended = lastEvent(events, "MatchEnded")
			expect(ended.winnerId).to.equal("p1")
			expect(ended.reason).to.equal("ScoreTarget")
		end)

		it("ends at the time cap with the leader as winner", function()
			local state, _ = activeMatch({ "p1", "p2" })
			local events = {}
			MatchSim.applyElim(state, RULES, "p2", "p1", events)
			MatchSim.tick(state, RULES, RULES.TimeCapSeconds + 1, events)
			local ended = lastEvent(events, "MatchEnded")
			expect(ended.winnerId).to.equal("p2")
			expect(ended.reason).to.equal("TimeCap")
		end)

		it("declares no winner on a tie at the time cap", function()
			local state, _ = activeMatch({ "p1", "p2" })
			local events = {}
			MatchSim.applyElim(state, RULES, "p1", "p2", events)
			MatchSim.applyElim(state, RULES, "p2", "p1", events)
			MatchSim.tick(state, RULES, RULES.TimeCapSeconds + 1, events)
			local ended = lastEvent(events, "MatchEnded")
			expect(ended.winnerId).never.to.be.ok()
		end)

		it("passes through Intermission between Results and Idle", function()
			local state, _ = activeMatch({ "p1", "p2" })
			local events = {}
			MatchSim.tick(state, RULES, RULES.TimeCapSeconds + 1, events)
			expect(state.phase).to.equal("Results")

			MatchSim.tick(state, RULES, RULES.ResultsSeconds + 1, events)
			expect(state.phase).to.equal("Intermission")
			expect(state.intermissionRemaining).to.equal(RULES.IntermissionSeconds)
			expect(lastEvent(events, "MatchReset")).to.be.ok()

			MatchSim.tick(state, RULES, RULES.IntermissionSeconds + 1, events)
			expect(state.phase).to.equal("Idle")
			expect(lastEvent(events, "IntermissionEnded")).to.be.ok()
		end)

		it("drops leavers' scores and admits joiners at zero mid-match", function()
			local state, _ = activeMatch({ "p1", "p2" })
			local events = {}
			MatchSim.applyElim(state, RULES, "p1", "p2", events)
			MatchSim.setPlayers(state, { p2 = true, p3 = true })
			expect(state.scores.p1).never.to.be.ok()
			expect(state.scores.p3).to.equal(0)
		end)
	end)

	describe("ModeRegistry", function()
		it("provides a default mode with complete rules", function()
			local mode = ModeRegistry.default()
			expect(mode.id).to.equal("FFA")
			expect(mode.rules.ScoreTarget > 0).to.equal(true)
			expect(mode.rules.TimeCapSeconds > 0).to.equal(true)
		end)

		it("registers every mode with the full hook surface", function()
			for _, mode in ModeRegistry.all() do
				expect(typeof(mode.onMatchStart)).to.equal("function")
				expect(typeof(mode.onPlayerSpawned)).to.equal("function")
				expect(typeof(mode.onElim)).to.equal("function")
				expect(typeof(mode.onMatchEnd)).to.equal("function")
				expect(typeof(mode.displayName)).to.equal("string")
			end
		end)

		it("resolves modes by id and rejects unknown ids", function()
			local default = ModeRegistry.default()
			expect(ModeRegistry.get(default.id).id).to.equal(default.id)
			expect(ModeRegistry.get("TDM").id).to.equal("TDM")
			expect(ModeRegistry.get("Nope")).never.to.be.ok()
		end)
	end)
end
