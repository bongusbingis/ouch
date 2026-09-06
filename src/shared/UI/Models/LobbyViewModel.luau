-- Name: LobbyViewModel.luau
-- Author: Jack C.
-- Description: Pure lobby presentation rules: party code sanitizing and formatting, and which actions and status text a party state offers its leader and members.
-- Created: 2026-08-17

--!strict

local LobbyViewModel = {}

export type PartyPresentation = {
	partyState: string,
	playText: string,
	playEnabled: boolean,
	showMatchmakingActivity: boolean,
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

function LobbyViewModel.partyPresentation(snapshot: any?, userId: number, busy: boolean): PartyPresentation
	if snapshot == nil then
		return {
			partyState = "LOADING PARTY",
			playText = "PLAY",
			playEnabled = false,
			showMatchmakingActivity = false,
		}
	end
	local isLeader = snapshot.leaderUserId == userId
	if snapshot.phase == "Lobby" and snapshot.returnQueuePending then
		return {
			partyState = "REGROUPING TO FIND PLAYERS",
			playText = "CANCEL",
			playEnabled = isLeader and not busy,
			showMatchmakingActivity = true,
		}
	elseif snapshot.phase == "Lobby" then
		return {
			partyState = if isLeader then "PRESS PLAY TO MATCHMAKE" else "WAITING FOR PARTY LEADER",
			playText = "PLAY",
			playEnabled = isLeader and not busy,
			showMatchmakingActivity = false,
		}
	elseif snapshot.phase == "Queued" then
		return {
			partyState = "SEARCHING FOR PLAYERS",
			playText = "CANCEL",
			playEnabled = isLeader and not busy,
			showMatchmakingActivity = true,
		}
	elseif snapshot.phase == "Claimed" then
		return {
			partyState = "FORMING MATCH",
			playText = "PLAY",
			playEnabled = false,
			showMatchmakingActivity = true,
		}
	elseif snapshot.phase == "Assigned" then
		return {
			partyState = "MATCH FOUND!",
			playText = "PLAY",
			playEnabled = false,
			showMatchmakingActivity = false,
		}
	end
	return {
		partyState = "TRAVELING TO MATCH",
		playText = "PLAY",
		playEnabled = false,
		showMatchmakingActivity = false,
	}
end

return LobbyViewModel
