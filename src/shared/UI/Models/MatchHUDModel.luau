-- Match copy derives from replicated scores and deadlines, never a local match timer.
--!strict

local MatchHUDModel = {}

-- Assigned by position in the mode's own team list rather than by team name, so
-- a mode whose sides are not called Red and Blue still reads as two sides. The
-- first team keeps Pink and the second Cyan, which is what Red and Blue already
-- were.
local TEAM_ACCENTS = { "Pink", "Cyan" }

function MatchHUDModel.teamAccent(index: number): string
	return TEAM_ACCENTS[(index - 1) % #TEAM_ACCENTS + 1]
end

function MatchHUDModel.isTeammate(entry: any, teamId: string?): boolean
	return teamId ~= nil and teamId ~= "" and entry.teamId == teamId and not entry.isLocal and entry.alive == true
end

function MatchHUDModel.teams(teams: { any }?): { any }
	local result = {}
	for index, team in teams or {} do
		table.insert(result, {
			id = team.id,
			label = string.upper(tostring(team.id)),
			score = team.score or 0,
			accent = MatchHUDModel.teamAccent(index),
		})
	end
	return result
end

function MatchHUDModel.standings(players: { any }): { any }
	local entries = {}
	for _, player in players do
		table.insert(entries, table.clone(player))
	end
	table.sort(entries, function(a, b)
		return if a.score == b.score then a.userId < b.userId else a.score > b.score
	end)
	local previous, rank = nil, 0
	for index, entry in entries do
		if entry.score ~= previous then
			rank = index
		end
		previous = entry.score
		entry.placement = rank
	end
	return entries
end

-- The standings strip shows the top `limit` rows and, when the local player sits
-- below the cut, their own row appended so the strip always answers "where am
-- I" without showing the whole match.
function MatchHUDModel.strip(entries: { any }, limit: number): { any }
	local rows = {}
	local localShown = false
	for index, entry in entries do
		if index > limit then
			break
		end
		table.insert(rows, entry)
		localShown = localShown or entry.isLocal == true
	end
	if not localShown then
		for index, entry in entries do
			if index > limit and entry.isLocal then
				table.insert(rows, entry)
				break
			end
		end
	end
	return rows
end

-- Team scoreboards get one column per team the mode declares; a crowded
-- free-for-all splits in two as well to keep twenty-player desktop boards
-- compact. Narrow views can scroll.
function MatchHUDModel.columns(entries: { any }, teams: { any }?, singleColumnMaxRows: number): { { any } }
	if teams ~= nil and #teams > 0 then
		local columns = {}
		local positionById = {}
		for position, team in teams do
			columns[position] = {}
			positionById[team.id] = position
		end
		for _, entry in entries do
			table.insert(columns[positionById[entry.teamId] or 1], entry)
		end
		return columns
	end
	if #entries <= singleColumnMaxRows then
		return { entries }
	end
	local half = math.ceil(#entries / 2)
	local first, second = {}, {}
	for index, entry in entries do
		table.insert(if index <= half then first else second, entry)
	end
	return { first, second }
end

function MatchHUDModel.build(snapshot: any, now: number): any
	local remaining = math.max(math.ceil(snapshot.timeRemaining or 0), 0)
	local rawTarget = snapshot.scoreTarget or 0
	-- A mode with no elimination target replicates zero. Infinity is guarded too,
	-- so a stale attribute cannot reach the objective line as the word "INF".
	local target = if rawTarget ~= rawTarget or rawTarget == math.huge then 0 else rawTarget
	local teams = MatchHUDModel.teams(snapshot.teams)
	local teamMode = #teams > 0
	-- Absent means combat, matching GameModes.IsCombat: every mode before
	-- Splashdown only ever ran combat HUD copy, so old callers need not pass it.
	local combat = snapshot.combat ~= false
	local scoreLabel = snapshot.scoreLabel or "ELIMS"
	local objective = if not combat
		then "RACE TO THE FINISH"
		else if target > 0 then `FIRST TO {target} ELIMINATIONS` else "SURVIVE UNTIL TIME RUNS OUT"

	-- Without an elimination target -- a headcount scoreboard -- the bars read
	-- against the total on the board instead, so they still fill to one.
	local teamTotal = 0
	for _, team in teams do
		teamTotal += team.score
	end
	local teamScoreMax = if target > 0 then target else teamTotal

	-- Rows always carry a player's own eliminations; the column headers carry
	-- whatever the mode scores by, which is not always the same thing. The legend
	-- says which, rather than calling a headcount a kill count.
	local footer = if not combat
		then scoreLabel
		else if not teamMode
			then "ELIMINATIONS"
			else if target > 0 then "ELIMINATIONS • TEAM TOTAL ABOVE" else "ELIMINATIONS • PLAYERS LEFT ABOVE"

	local scores
	if teamMode then
		local parts = {}
		for _, team in teams do
			table.insert(parts, `{team.label} {team.score}`)
		end
		scores = table.concat(parts, "   •   ")
		if snapshot.teamId then
			scores ..= `   |   YOU: {string.upper(snapshot.teamId)}`
		end
	else
		scores = `YOUR ELIMINATIONS  {snapshot.score or 0}`
	end
	local respawn = nil
	if snapshot.rewardsRecovery then
		respawn = "RESTORING REWARDS — PLEASE WAIT"
	elseif snapshot.eligible == false then
		respawn = "YOU’LL JOIN THE NEXT ROUND"
	elseif snapshot.alive == false then
		local seconds = math.max(math.ceil((snapshot.respawnAt or now) - now), 0)
		respawn = if seconds > 0 then `BACK IN {seconds}…` else "RESPAWNING…"
	elseif snapshot.opponentDeadline then
		respawn = `WAITING FOR OPPONENTS • {math.max(math.ceil(snapshot.opponentDeadline - now), 0)}s`
	end
	local entries = MatchHUDModel.standings(snapshot.players or {})
	local placement = nil
	for _, entry in entries do
		if entry.isLocal then
			placement = entry.placement
			break
		end
	end
	return {
		starting = snapshot.phase == "Starting",
		-- The clock only reads as urgent while the match itself is running, never during the Starting countdown.
		active = snapshot.phase == "Active",
		entries = entries,
		placement = placement,
		teamMode = teamMode,
		teams = teams,
		teamScoreMax = teamScoreMax,
		teamId = snapshot.teamId,
		score = snapshot.score or 0,
		remaining = remaining,
		target = target,
		scoreboardOpen = snapshot.scoreboardOpen == true,
		title = snapshot.title or "MATCH",
		clock = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60),
		objective = objective,
		scores = scores,
		footer = footer,
		scoreLabel = scoreLabel,
		combat = combat,
		respawn = respawn,
	}
end

return MatchHUDModel
