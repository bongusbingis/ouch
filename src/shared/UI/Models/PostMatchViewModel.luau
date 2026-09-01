-- Name: PostMatchViewModel.luau
-- Author: Jack C.
-- Description: Pure post-match presentation rules for party roles, action copy, request state, countdowns, and bounded responsive canvas sizing.
-- Created: 2026-08-31

--!strict

local PostMatchViewModel = {}

export type Action = "PlayAgain" | "CancelPlayAgain" | "ReturnToLobby" | "LeaveParty"

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
	local primaryText = if not isLeader
		then "WAITING FOR LEADER"
		else if replaySelected
			then "CANCEL PLAY AGAIN"
			else if partySize > 1 then "PLAY AGAIN WITH PARTY" else "PLAY AGAIN"
	local returnText = if isLeader
		then if partySize > 1 then "RETURN PARTY TO LOBBY" else "RETURN TO LOBBY"
		else "LEAVE PARTY & RETURN"
	local statusText
	if selfReturning or (requesting and pendingAction == "LeaveParty") then
		statusText = "LEAVING PARTY - RETURNING ONLY YOU"
	elseif groupReturning or (requesting and pendingAction == "ReturnToLobby") then
		statusText = if partySize > 1 then "RETURNING YOUR PARTY TO LOBBY" else "RETURNING TO LOBBY"
	elseif requesting then
		statusText = "SAVING YOUR PARTY'S CHOICE"
	elseif replaySelected then
		statusText = if isLeader
			then "YOUR PARTY IS STAYING FOR THE NEXT ROUND"
			else leaderName .. " CHOSE ANOTHER ROUND"
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
	}
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
