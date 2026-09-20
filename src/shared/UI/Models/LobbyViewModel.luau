-- Description: Pure lobby presentation rules: party code sanitizing and formatting, and which actions and status text a party state offers its leader and members.

--!strict

local LobbyViewModel = {}

export type QueueChoice = { partyId: string, leaderUserId: number, queueId: string }

-- An idle leader must explicitly choose this session. A server default alone is
-- not a choice. Members and in-flight parties display their authoritative queue.
function LobbyViewModel.selectedQueueId(snapshot: any?, userId: number, choice: QueueChoice?): string?
	if snapshot == nil then
		return nil
	end
	if snapshot.leaderUserId ~= userId or snapshot.phase ~= "Lobby" or snapshot.returnQueuePending then
		return snapshot.queueId
	end
	if
		choice
		and choice.partyId == snapshot.partyId
		and choice.leaderUserId == snapshot.leaderUserId
		and choice.queueId == snapshot.queueId
	then
		return choice.queueId
	end
	return nil
end

export type PartyPresentation = {
	partyState: string,
	playText: string,
	playEnabled: boolean,
	showMatchmakingActivity: boolean,
	canPickQueue: boolean,
}

function LobbyViewModel.sanitizeCode(value: string): string
	return string.sub(string.gsub(value, "%D", ""), 1, 6)
end

function LobbyViewModel.formatJoinCode(value: string): string
	local digits = LobbyViewModel.sanitizeCode(value)
	if #digits <= 3 then
		return digits
	end
	return `{string.sub(digits, 1, 3)}-{string.sub(digits, 4)}`
end

function LobbyViewModel.formatPartyCode(code: string?, visible: boolean): string
	if not visible or code == nil or #code ~= 6 then
		return "PARTY CODE: XXX-XXX"
	end
	return `PARTY CODE: {string.sub(code, 1, 3)}-{string.sub(code, 4, 6)}`
end

-- The queue is the leader's to change only while the party is idle in the
-- lobby: a queued, claimed or regrouping party already belongs to a queue.
function LobbyViewModel.partyPresentation(
	snapshot: any?,
	userId: number,
	busy: boolean,
	selectedQueueId: string?
): PartyPresentation
	if snapshot == nil then
		return {
			partyState = "LOADING PARTY",
			playText = "PLAY",
			playEnabled = false,
			showMatchmakingActivity = false,
			canPickQueue = false,
		}
	end
	local isLeader = snapshot.leaderUserId == userId
	if snapshot.phase == "Lobby" and snapshot.returnQueuePending then
		return {
			partyState = "MATCHMAKING IN PROGRESS — REGROUPING PARTY",
			playText = "CANCEL",
			playEnabled = isLeader and not busy,
			showMatchmakingActivity = true,
			canPickQueue = false,
		}
	elseif snapshot.phase == "Lobby" then
		return {
			partyState = if not isLeader
				then "WAITING FOR PARTY LEADER"
				elseif selectedQueueId == nil then "SELECT A GAME MODE"
				else "CLICK PLAY TO ENTER MATCHMAKING",
			playText = "PLAY",
			playEnabled = isLeader and not busy and selectedQueueId ~= nil and selectedQueueId == snapshot.queueId,
			showMatchmakingActivity = false,
			canPickQueue = isLeader and not busy,
		}
	elseif snapshot.phase == "Queued" then
		return {
			partyState = "MATCHMAKING IN PROGRESS — SEARCHING FOR PLAYERS",
			playText = "CANCEL",
			playEnabled = isLeader and not busy,
			showMatchmakingActivity = true,
			canPickQueue = false,
		}
	elseif snapshot.phase == "Claimed" then
		return {
			partyState = "PLAYERS FOUND — PREPARING YOUR MATCH",
			playText = "PLAY",
			playEnabled = false,
			showMatchmakingActivity = true,
			canPickQueue = false,
		}
	elseif snapshot.phase == "Assigned" then
		return {
			partyState = "MATCH READY — JOINING SOON",
			playText = "PLAY",
			playEnabled = false,
			showMatchmakingActivity = false,
			canPickQueue = false,
		}
	end
	return {
		partyState = "MATCH READY — TELEPORTING",
		playText = "PLAY",
		playEnabled = false,
		showMatchmakingActivity = false,
		canPickQueue = false,
	}
end

return LobbyViewModel
