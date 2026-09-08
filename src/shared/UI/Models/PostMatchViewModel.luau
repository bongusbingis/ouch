-- Description: Pure post-match presentation rules for party roles, action copy, request state, countdowns, and bounded responsive canvas sizing.

--!strict

local PostMatchViewModel = {}

export type Action = "PlayAgain" | "CancelPlayAgain" | "ReturnToLobby" | "LeaveParty" | "FindMatch"

export type ActionModel = {
	isLeader: boolean,
	partySize: number,
	partyNames: { string },
	primaryText: string,
	returnText: string,
	returnAction: "ReturnToLobby" | "LeaveParty",
	statusText: string,
	replaySelected: boolean,
	busy: boolean,
	primaryEnabled: boolean,
}

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
	pendingAction: Action?
): ActionModel
	local partyLeaderId, partySize, partyNames, leaderName = partyInfo(localUserId, party)
	local leaderUserId = if status and status.leaderUserId then status.leaderUserId else partyLeaderId
	local isLeader = leaderUserId == localUserId
	local replaySelected = status ~= nil and status.state == "PlayAgain"
	local selfReturning = status ~= nil and status.selfReturning == true
	local groupReturning = status ~= nil and status.state == "Returning"
	local busy = requesting or selfReturning or groupReturning
	local canReplay = status == nil or status.canReplay ~= false
	local primaryText = if not isLeader
		then "WAITING FOR LEADER"
		else if not canReplay
			then "FIND PLAYERS"
			else if replaySelected
				then "NEXT ROUND ✓"
				else if partySize > 1 then "PLAY AGAIN WITH PARTY" else "PLAY AGAIN"
	local returnText = if isLeader
		then if partySize > 1 then "RETURN PARTY TO LOBBY" else "RETURN TO LOBBY"
		else "LEAVE PARTY & RETURN"
	local statusText
	if selfReturning or (requesting and pendingAction == "LeaveParty") then
		statusText = "LEAVING PARTY - RETURNING ONLY YOU"
	elseif (status and status.findingPlayers) or (requesting and pendingAction == "FindMatch") then
		statusText = "HEADING TO THE LOBBY TO FIND PLAYERS"
	elseif groupReturning or (requesting and pendingAction == "ReturnToLobby") then
		statusText = if partySize > 1 then "RETURNING YOUR PARTY TO LOBBY" else "RETURNING TO LOBBY"
	elseif requesting then
		statusText = "SAVING YOUR PARTY'S CHOICE"
	elseif not canReplay then
		statusText = if isLeader then "LET'S FIND MORE PLAYERS" else leaderName .. " CAN FIND YOUR NEXT MATCH"
	elseif replaySelected then
		statusText = if isLeader
			then if partySize > 1
				then "YOUR PARTY IS STAYING FOR THE NEXT ROUND"
				else "YOU'RE STAYING FOR THE NEXT ROUND"
			else "YOUR PARTY IS STAYING — YOUR LEADER CAN RETURN TO LOBBY"
	elseif not isLeader then
		statusText = "WAITING FOR " .. leaderName .. " - YOU CAN LEAVE WITHOUT MOVING THE PARTY"
	else
		statusText = "READY FOR ANOTHER ROUND?"
	end

	return {
		isLeader = isLeader,
		partySize = partySize,
		partyNames = partyNames,
		primaryText = primaryText,
		returnText = returnText,
		returnAction = if isLeader then "ReturnToLobby" else "LeaveParty",
		statusText = statusText,
		replaySelected = replaySelected,
		busy = busy,
		primaryEnabled = isLeader and not busy and (not replaySelected or not canReplay),
	}
end

function PostMatchViewModel.destination(status: any?, partySize: number): string?
	if status == nil then
		return nil
	end
	if status.nextDestination == "Lobby" then
		return if status.selfReturning or partySize <= 1
			then "RETURNING TO LOBBY WHEN THE TIMER ENDS"
			else "YOUR PARTY RETURNS TO LOBBY WHEN THE TIMER ENDS"
	elseif status.nextDestination == "Arena" then
		return "NEXT ROUND WHEN THE TIMER ENDS"
	end
	return nil
end

function PostMatchViewModel.remainingSeconds(endsAt: number, now: number): number
	return math.max(math.ceil(endsAt - now), 0)
end

function PostMatchViewModel.canvasSize(width: number, height: number): (number, number, boolean)
	local canvasWidth = math.min(math.max(width, 0), 1920)
	local canvasHeight = math.min(math.max(height, 0), 1080)
	if height > width then
		canvasHeight = math.min(canvasHeight, canvasWidth * 0.75)
	end
	return canvasWidth, canvasHeight, canvasWidth < 1000 or canvasHeight < 620
end

return table.freeze(PostMatchViewModel)
