-- Description: Pure post-match presentation rules: party roles and the final action copy, footer status lines, the countdown caption, the stage heading, per-stat value formatting, the season bar reveal, and countdown rounding.

--!strict

local SplashdownHUDModel = require(script.Parent.SplashdownHUDModel)
local formatNumber = require(script.Parent.NumberText)

local PostMatchViewModel = {}

export type Action = "PlayAgain" | "CancelPlayAgain" | "ReturnToLobby" | "LeaveParty" | "FindMatch"

export type PrimaryStyle = "Primary" | "Done" | "Waiting"

export type ActionModel = {
	isLeader: boolean,
	partySize: number,
	partyNames: { string },
	leaderName: string,
	primaryText: string,
	primaryStyle: PrimaryStyle,
	primaryIcon: string?,
	returnText: string,
	returnAction: "ReturnToLobby" | "LeaveParty",
	statusText: string,
	replaySelected: boolean,
	busy: boolean,
	primaryEnabled: boolean,
}

export type Countdown = { caption: string, value: string }

export type SeasonReveal = { startFraction: number, endFraction: number, tierUp: boolean }

local function partyInfo(localUserId: number, party: any?): (number, number, { string }, string)
	if party == nil then
		return localUserId, 1, {}, "YOU"
	end
	local names = {}
	local leaderName = "YOUR LEADER"
	for _, member in party.members do
		local name = if member.isLocal then "YOU" else string.upper(member.displayName)
		table.insert(names, name)
		if member.userId == party.leaderUserId then
			leaderName = name
		end
	end
	return party.leaderUserId, #party.members, names, leaderName
end

function PostMatchViewModel.actions(
	localUserId: number,
	party: any?,
	status: any?,
	requesting: boolean,
	pendingAction: Action?,
	departing: boolean?
): ActionModel
	local partyLeaderId, partySize, partyNames, leaderName = partyInfo(localUserId, party)
	local leaderUserId = if status and status.leaderUserId then status.leaderUserId else partyLeaderId
	local isLeader = leaderUserId == localUserId
	local replaySelected = status ~= nil and status.state == "PlayAgain"
	local selfReturning = status ~= nil and status.selfReturning == true
	local groupReturning = status ~= nil and status.state == "Returning"
	local busy = requesting or selfReturning or groupReturning or departing == true
	local canReplay = status == nil or status.canReplay ~= false

	local primaryText, primaryStyle: PrimaryStyle
	local primaryIcon: string? = nil
	if busy then
		primaryText, primaryStyle = "PLEASE WAIT…", "Waiting"
	elseif not isLeader then
		primaryText, primaryStyle = "LEADER DECIDES", "Waiting"
	elseif not canReplay then
		primaryText, primaryStyle = "FIND PLAYERS", "Primary"
	elseif replaySelected then
		-- The confirmation tick is drawn from the Check icon, not a Unicode glyph (fallback fonts render it as a root sign).
		primaryText, primaryStyle, primaryIcon = "NEXT ROUND", "Done", "Check"
	else
		primaryText, primaryStyle = "PLAY AGAIN", "Primary"
	end
	local returnText = if isLeader then "LOBBY" else "LEAVE PARTY"

	local statusText
	if departing then
		statusText = if selfReturning
			then "LEAVING YOUR PARTY · HEADING TO THE LOBBY"
			else if partySize > 1 then "YOUR PARTY IS HEADING TO THE LOBBY" else "HEADING TO THE LOBBY"
	elseif selfReturning or (requesting and pendingAction == "LeaveParty") then
		statusText = "LEAVING YOUR PARTY · HEADING TO THE LOBBY"
	elseif (status and status.findingPlayers) or (requesting and pendingAction == "FindMatch") then
		statusText = "HEADING TO THE LOBBY TO FIND PLAYERS"
	elseif groupReturning or (requesting and pendingAction == "ReturnToLobby") then
		statusText = if partySize > 1 then "YOUR PARTY IS HEADING TO THE LOBBY" else "HEADING TO THE LOBBY"
	elseif requesting then
		statusText = "SAVING YOUR CHOICE…"
	elseif not canReplay then
		statusText = if isLeader
			then "NOT ENOUGH PLAYERS · FIND SOME IN THE LOBBY"
			else leaderName .. " CAN FIND YOUR NEXT MATCH"
	elseif replaySelected then
		statusText = if isLeader
			then if partySize > 1 then "YOUR PARTY STAYS FOR THE NEXT ROUND" else "YOU'RE IN FOR THE NEXT ROUND"
			else "YOUR PARTY STAYS · LEAVE PARTY TO GO ALONE"
	elseif not isLeader then
		statusText = "WAITING FOR " .. leaderName .. " · LEAVE PARTY TO GO ALONE"
	else
		statusText = "READY FOR ANOTHER ROUND?"
	end

	return {
		isLeader = isLeader,
		partySize = partySize,
		partyNames = partyNames,
		leaderName = leaderName,
		primaryText = primaryText,
		primaryStyle = primaryStyle,
		primaryIcon = primaryIcon,
		returnText = returnText,
		returnAction = if isLeader then "ReturnToLobby" else "LeaveParty",
		statusText = statusText,
		replaySelected = replaySelected,
		busy = busy,
		primaryEnabled = isLeader and not busy and (not replaySelected or not canReplay),
	}
end

function PostMatchViewModel.countdown(
	status: any?,
	partySize: number,
	remaining: number,
	departing: boolean?
): Countdown
	if departing then
		return { caption = "HEADING TO", value = "LOBBY" }
	end
	local value = `{remaining}s`
	if status == nil then
		return { caption = "RESULTS END IN", value = value }
	end
	if status.nextDestination == "Lobby" then
		return {
			caption = if status.selfReturning or partySize <= 1 then "LOBBY IN" else "PARTY LEAVES IN",
			value = value,
		}
	elseif status.nextDestination == "Arena" then
		return { caption = "NEXT ROUND IN", value = value }
	end
	return { caption = "RESULTS END IN", value = value }
end

function PostMatchViewModel.kicker(modeName: string, eyebrow: string): string
	return string.upper(modeName) .. " · " .. eyebrow
end

-- The detail pill only earns its place when it adds something the kicker and title do not;
-- generic "round complete" restatements are dropped.
local GENERIC_DETAILS = {
	["ROUND COMPLETE"] = true,
	["MATCH COMPLETE"] = true,
	["ROUND OVER"] = true,
	["ROUND ENDED"] = true,
}

function PostMatchViewModel.detail(detail: string?, eyebrow: string): string?
	if detail == nil or detail == "" or detail == eyebrow or GENERIC_DETAILS[detail] then
		return nil
	end
	return detail
end

function PostMatchViewModel.stageHeading(
	teamMode: boolean,
	podiumCount: number,
	tied: boolean,
	standings: boolean
): string
	if standings then
		return "FINAL STANDINGS"
	end
	if podiumCount == 0 then
		return if tied then "DEAD HEAT" else "READY FOR THE NEXT ONE"
	end
	return if teamMode then "WINNING TEAM STANDOUTS" else "TOP FINISHERS"
end

-- Team-scope podium plates show each player's own eliminations (contribution),
-- not the team score, so they keep the elimination unit even when the mode's
-- score label counts something else (Infection scores headcount as PLAYERS).
function PostMatchViewModel.podiumScoreLabel(teamMode: boolean, scoreLabel: string): string
	return if teamMode then "ELIMS" else scoreLabel
end

function PostMatchViewModel.statText(stat: { id: string, value: number }): string
	if stat.id == "TotalTime" then
		return SplashdownHUDModel.formatTime(stat.value)
	end
	if stat.id == "BestFinish" or stat.id == "Placement" then
		return if stat.value >= 1 then SplashdownHUDModel.ordinal(stat.value) else "—"
	end
	return formatNumber(stat.value)
end

function PostMatchViewModel.seasonReveal(season: any): SeasonReveal
	local span = math.max(season.xpForNextTier, 1)
	local endFraction = math.clamp(season.xpIntoTier / span, 0, 1)
	local tierUp = season.afterTier > season.beforeTier
	local gained = math.max(season.afterXp - season.beforeXp, 0)
	local startFraction = if tierUp then 0 else math.clamp((season.xpIntoTier - gained) / span, 0, endFraction)
	return { startFraction = startFraction, endFraction = endFraction, tierUp = tierUp }
end

function PostMatchViewModel.remainingSeconds(endsAt: number, now: number): number
	return math.max(math.ceil(endsAt - now), 0)
end

return table.freeze(PostMatchViewModel)
