-- Description: Sole owner of post-match result delivery and party replay intent, building result packets from match and progression facts, sending them per party group, and validating the actions players request from the results screen.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PostMatch = Shared:WaitForChild("Game"):WaitForChild("PostMatch")
local PostMatchActionPolicy = require(PostMatch:WaitForChild("PostMatchActionPolicy"))
local PostMatchResult = require(PostMatch:WaitForChild("PostMatchResult"))

local ArenaReturnService = require(script.Parent.ArenaReturnService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local MatchService = require(script.Parent.MatchService)
local ProgressionService = require(script.Parent.ProgressionService)

local PostMatchService = {}

export type Status = {
	resultId: string,
	revision: number,
	state: "Interactive" | "PlayAgain" | "Returning",
	leaderUserId: number,
	requestedByUserId: number?,
	error: string?,
	party: PostMatchResult.Party?,
	selfReturning: boolean?,
	nextDestination: ("Arena" | "Lobby")?,
	canReplay: boolean?,
	findingPlayers: boolean?,
}

local started = false
local activeResult: PostMatchResult.GlobalResult? = nil
local statusByGroup: { [string]: Status } = {}

local function groupKey(player: Player): string
	return ArenaSessionService.partyIdFor(player) or `solo:{player.UserId}`
end

local function groupPlayers(player: Player): { Player }
	return ArenaSessionService.partyPlayersFor(player)
end

local function statusFor(player: Player): Status?
	return statusByGroup[groupKey(player)]
end

local function partyFor(player: Player): PostMatchResult.Party
	local leaderUserId = ArenaSessionService.effectiveLeaderUserIdFor(player)
	local members = {}
	for _, member in groupPlayers(player) do
		table.insert(members, {
			userId = member.UserId,
			username = member.Name,
			displayName = member.DisplayName,
			isLeader = member.UserId == leaderUserId,
			isLocal = member == player,
			present = member.Parent == Players,
		})
	end
	return {
		partyId = ArenaSessionService.partyIdFor(player) or `solo:{player.UserId}`,
		leaderUserId = leaderUserId,
		members = members,
	}
end

local function statusPacket(player: Player, status: Status): Status
	local packet = table.clone(status)
	packet.party = partyFor(player)
	packet.selfReturning = ArenaReturnService.isSeparatingReturn(player)
	packet.canReplay = #MatchService.availableModes() > 0
	packet.nextDestination = if packet.selfReturning or status.state == "Returning"
		then "Lobby"
		else if ArenaReturnService.isPartyRetained(player) then "Arena" else "Lobby"
	return packet
end

local function fireStatus(player: Player, status: Status)
	Network.fire("PostMatchStatus", player, statusPacket(player, status))
end

local function publishGroup(player: Player)
	local status = statusFor(player)
	if status == nil then
		return
	end
	local effectiveLeader = ArenaSessionService.effectiveLeaderUserIdFor(player)
	if status.leaderUserId ~= effectiveLeader then
		status.leaderUserId = effectiveLeader
		status.revision += 1
	end
	for _, member in groupPlayers(player) do
		fireStatus(member, status)
	end
end

local statusPublishScheduled = false
local function scheduleStatuses()
	if statusPublishScheduled then
		return
	end
	statusPublishScheduled = true
	task.defer(function()
		statusPublishScheduled = false
		if activeResult == nil or MatchService.phase() ~= "Results" then
			return
		end
		local published = {}
		for _, player in Players:GetPlayers() do
			local key = groupKey(player)
			local status = statusFor(player)
			if status and not published[key] then
				published[key] = true
				status.revision += 1
				publishGroup(player)
			end
		end
	end)
end

local function sendResult(player: Player, result: PostMatchResult.GlobalResult)
	if not ArenaSessionService.isPlayable(player) then
		return
	end
	local key = groupKey(player)
	local status = statusByGroup[key]
	local leaderChanged = false
	if status == nil then
		status = {
			resultId = result.resultId,
			revision = 1,
			state = if ArenaReturnService.isPartyRetained(player) then "PlayAgain" else "Interactive",
			leaderUserId = ArenaSessionService.effectiveLeaderUserIdFor(player),
		}
		statusByGroup[key] = status
	else
		local effectiveLeader = ArenaSessionService.effectiveLeaderUserIdFor(player)
		if status.leaderUserId ~= effectiveLeader then
			status.leaderUserId = effectiveLeader
			status.revision += 1
			leaderChanged = true
		end
	end
	local personal = PostMatchResult.forPlayer(
		result,
		player.UserId,
		ProgressionService.summaryFor(player, result.resultId),
		partyFor(player)
	)
	if personal then
		Network.fire("PostMatchResult", player, personal)
		if leaderChanged then
			publishGroup(player)
		else
			fireStatus(player, status)
		end
	end
end

local function beginResult()
	local result = MatchService.resultSnapshot()
	if result == nil then
		return
	end
	activeResult = result
	table.clear(statusByGroup)

	for _, player in Players:GetPlayers() do
		sendResult(player, result)
	end
end

local function validRequest(_player: Player, action: any, resultId: any)
	return (
		action == "PlayAgain"
		or action == "CancelPlayAgain"
		or action == "ReturnToLobby"
		or action == "LeaveParty"
		or action == "FindMatch"
	)
		and typeof(resultId) == "string"
		and #resultId > 0
		and #resultId <= 100,
		"invalid_request"
end

local function request(player: Player, action: string, resultId: string)
	local result = activeResult
	local status = statusFor(player)
	if
		result == nil
		or status == nil
		or result.resultId ~= resultId
		or status.resultId ~= resultId
		or MatchService.phase() ~= "Results"
	then
		return { ok = false, error = "results_expired" }
	end
	if status.state == "Returning" then
		return { ok = false, error = "return_in_progress", status = statusPacket(player, status) }
	end
	local leaderUserId = ArenaSessionService.effectiveLeaderUserIdFor(player)
	local partySize = #ArenaSessionService.partyMemberUserIdsFor(player)
	local allowed, policyError = PostMatchActionPolicy.validate(
		action :: PostMatchActionPolicy.Action,
		player.UserId,
		leaderUserId,
		partySize,
		Workspace:GetServerTimeNow(),
		result.interactiveAt
	)
	if not allowed then
		return { ok = false, error = policyError, status = statusPacket(player, status) }
	end

	if action == "LeaveParty" then
		local ok, reason = ArenaReturnService.leavePartyAndReturn(player)
		return { ok = ok, error = reason, status = statusPacket(player, status) }
	end

	if action == "ReturnToLobby" or action == "FindMatch" then
		local previousState = status.state
		status.revision += 1
		status.state = "Returning"
		status.requestedByUserId = player.UserId
		status.error = nil
		status.findingPlayers = action == "FindMatch"
		publishGroup(player)
		local ok, reason = ArenaReturnService.returnParty(player, action == "FindMatch")
		if not ok then
			status.revision += 1
			status.state = previousState
			status.requestedByUserId = nil
			status.findingPlayers = nil
			publishGroup(player)
		else
			ArenaReturnService.releaseParty(player)
		end
		return { ok = ok, error = reason, status = statusPacket(player, status) }
	end
	if action == "PlayAgain" then
		local ok, reason = ArenaReturnService.retainParty(player)
		if not ok then
			return { ok = false, error = reason or "replay_unavailable", status = statusPacket(player, status) }
		end
		status.state = "PlayAgain"
		status.requestedByUserId = player.UserId
		status.error = nil
	else
		ArenaReturnService.releaseParty(player)
		status.state = "Interactive"
		status.requestedByUserId = nil
		status.error = nil
	end
	status.leaderUserId = leaderUserId
	status.revision += 1
	publishGroup(player)
	return { ok = true, status = statusPacket(player, status) }
end

function PostMatchService.start()
	if started then
		return
	end
	started = true

	Network.handleProtected("PostMatchRequest", {
		rateLimit = 3,
		validate = validRequest,
	}, request)

	MatchService.onEvent(function(event)
		if event.kind == "MatchEnded" then
			beginResult()
		elseif event.kind == "MatchReset" then
			activeResult = nil
			table.clear(statusByGroup)
		end
	end)
	ArenaSessionService.onReady(function(player)
		local result = activeResult
		if result and MatchService.phase() == "Results" then
			sendResult(player, result)
		end
	end)
	ProgressionService.onSummary(function(player, _summary, resultId)
		local result = activeResult
		if result and result.resultId == resultId and MatchService.phase() == "Results" then
			sendResult(player, result)
		end
	end)
	ArenaReturnService.onReturnInterrupted(function(player, reason)
		local result = activeResult
		local status = statusFor(player)
		if result == nil or status == nil or MatchService.phase() ~= "Results" then
			return
		end
		if status.state ~= "Returning" then
			fireStatus(player, status)
			return
		end
		status.revision += 1
		status.state = "Interactive"
		status.requestedByUserId = nil
		status.error = reason
		status.findingPlayers = nil
		publishGroup(player)
	end)
	ArenaSessionService.onRoundEligibilityChanged(scheduleStatuses)
	Players.PlayerRemoving:Connect(scheduleStatuses)
end

return PostMatchService
