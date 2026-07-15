--!strict

local SimUtil = require(script.Parent.SimUtil)
local GameMode = require(script.Parent.Parent.Modes.GameMode)

-- Pure match rules: scoring, win conditions, and the phase machine. The
-- active mode's MatchRules are passed in by the caller, so the same machine
-- serves every mode. Deaths/respawns/maps are consequences applied by
-- MatchService; this module only decides scores and match flow.

local MatchSim = {}

type MatchRules = GameMode.MatchRules

export type MatchPhase = "Idle" | "Active" | "Results" | "Intermission"

export type MatchState = {
	phase: MatchPhase,
	timeRemaining: number,
	resultsRemaining: number,
	intermissionRemaining: number,
	scores: { [string]: number },
	winnerId: string?,
}

export type MatchEvent = {
	kind: string, -- MatchStarted | ScoreChanged | MatchEnded | MatchReset | IntermissionEnded
	playerId: string?,
	score: number?,
	winnerId: string?,
	reason: string?, -- MatchEnded: "ScoreTarget" | "TimeCap"
}

function MatchSim.newState(): MatchState
	return {
		phase = "Idle",
		timeRemaining = 0,
		resultsRemaining = 0,
		intermissionRemaining = 0,
		scores = {},
		winnerId = nil,
	}
end

-- Reconciles the score table with the currently present players. Joiners
-- enter at 0 mid-match; leavers forfeit their score.
function MatchSim.setPlayers(state: MatchState, playerIds: { [string]: boolean })
	for playerId in playerIds do
		if state.scores[playerId] == nil then
			state.scores[playerId] = 0
		end
	end
	for _, playerId in SimUtil.sortedKeys(state.scores) do
		if not playerIds[playerId] then
			state.scores[playerId] = nil
		end
	end
end

function MatchSim.start(state: MatchState, rules: MatchRules, events: { MatchEvent })
	state.phase = "Active"
	state.timeRemaining = rules.TimeCapSeconds
	state.resultsRemaining = 0
	state.winnerId = nil
	for _, playerId in SimUtil.sortedKeys(state.scores) do
		state.scores[playerId] = 0
	end
	table.insert(events, { kind = "MatchStarted" })
end

-- Highest score wins; a tie yields no winner.
local function leader(state: MatchState): string?
	local bestId: string? = nil
	local bestScore = -1
	local tied = false
	for _, playerId in SimUtil.sortedKeys(state.scores) do
		local score = state.scores[playerId]
		if score > bestScore then
			bestId = playerId
			bestScore = score
			tied = false
		elseif score == bestScore then
			tied = true
		end
	end
	return if tied then nil else bestId
end

local function endMatch(state: MatchState, rules: MatchRules, reason: string, events: { MatchEvent })
	state.phase = "Results"
	state.resultsRemaining = rules.ResultsSeconds
	state.winnerId = leader(state)
	table.insert(events, { kind = "MatchEnded", winnerId = state.winnerId, reason = reason })
end

-- One point per elimination. Environmental deaths (no source, or self) and
-- eliminations outside an active match score nothing.
function MatchSim.applyElim(
	state: MatchState,
	rules: MatchRules,
	sourceId: string?,
	targetId: string?,
	events: { MatchEvent }
)
	if state.phase ~= "Active" then
		return
	end
	if sourceId == nil or targetId == nil or sourceId == targetId then
		return
	end
	if state.scores[sourceId] == nil then
		return
	end

	local score = state.scores[sourceId] + 1
	state.scores[sourceId] = score
	table.insert(events, { kind = "ScoreChanged", playerId = sourceId, score = score })

	if score >= rules.ScoreTarget then
		endMatch(state, rules, "ScoreTarget", events)
	end
end

function MatchSim.tick(state: MatchState, rules: MatchRules, dt: number, events: { MatchEvent })
	if state.phase == "Active" then
		state.timeRemaining = math.max(state.timeRemaining - dt, 0)
		if state.timeRemaining <= 0 then
			endMatch(state, rules, "TimeCap", events)
		end
	elseif state.phase == "Results" then
		state.resultsRemaining = math.max(state.resultsRemaining - dt, 0)
		if state.resultsRemaining <= 0 then
			state.phase = "Intermission"
			state.intermissionRemaining = rules.IntermissionSeconds
			state.winnerId = nil
			table.insert(events, { kind = "MatchReset" })
		end
	elseif state.phase == "Intermission" then
		state.intermissionRemaining = math.max(state.intermissionRemaining - dt, 0)
		if state.intermissionRemaining <= 0 then
			state.phase = "Idle"
			table.insert(events, { kind = "IntermissionEnded" })
		end
	end
end

return MatchSim
