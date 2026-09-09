-- Match copy derives from replicated scores and deadlines, never a local match timer.
--!strict

local MatchHUDModel = {}

function MatchHUDModel.isTeammate(entry: any, teamId: string?): boolean
	return teamId ~= nil and teamId ~= "" and entry.teamId == teamId and not entry.isLocal and entry.alive == true
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

function MatchHUDModel.build(snapshot: any, now: number): any
	local remaining = math.max(math.ceil(snapshot.timeRemaining or 0), 0)
	local target = snapshot.scoreTarget or 0
	local objective = if target > 0 then `FIRST TO {target} ELIMINATIONS` else "SURVIVE UNTIL TIME RUNS OUT"
	local scores = if snapshot.teamMode
		then `RED {snapshot.redScore or 0}   •   BLUE {snapshot.blueScore or 0}`
		else `YOUR ELIMINATIONS  {snapshot.score or 0}`
	if snapshot.teamMode and snapshot.teamId then
		scores ..= `   |   YOU: {string.upper(snapshot.teamId)}`
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
		entries = entries,
		placement = placement,
		teamMode = snapshot.teamMode == true,
		teamId = snapshot.teamId,
		redScore = snapshot.redScore or 0,
		blueScore = snapshot.blueScore or 0,
		score = snapshot.score or 0,
		remaining = remaining,
		target = target,
		scoreboardOpen = snapshot.scoreboardOpen == true,
		title = snapshot.title or "MATCH",
		clock = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60),
		objective = objective,
		scores = scores,
		respawn = respawn,
	}
end

return MatchHUDModel
