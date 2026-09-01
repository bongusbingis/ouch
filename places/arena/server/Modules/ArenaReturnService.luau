-- Name: ArenaReturnService.luau
-- Author: Jack C.
-- Description: Sends lobby-originated players back to the lobby place when a match resets, grouping one teleport per party, carrying the return payload, and retrying transient teleport failures while leaving direct joins alone.
-- Created: 2026-08-18

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local Loading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Loading"))
local PostMatchConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("PostMatch"))
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Matchmaking = Shared:WaitForChild("Game"):WaitForChild("Matchmaking")
local ReturnPayload = require(Matchmaking:WaitForChild("ReturnPayload"))
local TeleportRetryCoordinator = require(Matchmaking:WaitForChild("TeleportRetryCoordinator"))
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local MatchService = require(script.Parent.MatchService)
local ProgressionService = require(script.Parent.ProgressionService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local Env = require(script.Parent.Parent.Env)

local ArenaReturnService = {}

local started = false
local staying: { [Player]: boolean } = {}
local pendingReturn: { [Player]: boolean } = {}
local separatingReturn: { [Player]: boolean } = {}
local presentationReady: { [number]: boolean } = {}
local preparing: { [Player]: number | "Manual" } = {}
local retainedPartyIds: { [string]: boolean } = {}
local interruptedListeners: { (Player, string) -> () } = {}
local returnGeneration = 0
local coordinator = TeleportRetryCoordinator.new("Lobby")

local function setPartyEligible(player: Player, eligible: boolean)
	for _, member in ArenaSessionService.partyPlayersFor(player) do
		ArenaSessionService.setRoundEligible(member, eligible)
	end
end

local function dispatchInterrupted(player: Player, reason: string)
	for _, listener in table.clone(interruptedListeners) do
		local ok, err = pcall(listener, player, reason)
		if not ok then
			warn(`[ArenaReturnService] interrupted listener failed: {err}`)
		end
	end
end

local function partyGroups(): { [string]: { Player } }
	local groups: { [string]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		if
			staying[player]
			or pendingReturn[player]
			or coordinator:IsTracked(player)
			or not ArenaSessionService.isAdmitted(player)
		then
			continue
		end
		local partyId = ArenaSessionService.partyIdFor(player)
		if partyId == nil then
			continue
		end
		if retainedPartyIds[partyId] then
			continue
		end
		local group = groups[partyId]
		if group == nil then
			group = {}
			groups[partyId] = group
		end
		table.insert(group, player)
	end
	return groups
end

local function sendGroup(partyId: string, matchId: string, players: { Player }, generation: number?)
	local result = MatchService.resultSnapshot()
	if
		result
		and not ProgressionService.awaitCommitted(players, result.resultId, PostMatchConfig.RewardCommitTimeoutSeconds)
	then
		for _, player in players do
			dispatchInterrupted(player, "rewards_pending")
		end
		return
	end
	local memberUserIds = ArenaSessionService.partyMemberUserIdsFor(players[1])
	local prepared = coordinator:Prepare(Env.LobbyPlaceId, players, function(_retryPlayers)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(ReturnPayload.build(partyId, matchId, memberUserIds))
		return options
	end)
	if #prepared == 0 then
		return
	end
	for _, player in prepared do
		preparing[player] = generation or "Manual"
	end

	local deadline = os.clock() + Loading.TeleportPresentationFallbackSeconds
	while (generation == nil or generation == returnGeneration) and os.clock() < deadline do
		local allPresented = true
		for _, player in prepared do
			if player.Parent == Players and not presentationReady[player.UserId] then
				allPresented = false
				break
			end
		end
		if allPresented then
			break
		end
		task.wait(0.1)
	end
	if generation ~= nil and generation ~= returnGeneration then
		for _, player in prepared do
			preparing[player] = nil
			coordinator:Clear(player)
		end
		return
	end

	local currentPlayers = {}
	for _, player in prepared do
		preparing[player] = nil
		if player.Parent == Players and ArenaSessionService.partyIdFor(player) == partyId then
			table.insert(currentPlayers, player)
		else
			coordinator:Clear(player)
		end
	end
	if #currentPlayers == 0 then
		return
	end

	coordinator:StartPrepared(currentPlayers)
end

local function returnParties()
	local session = ArenaSessionService.getSnapshot()
	if session == nil then
		return
	end
	returnGeneration += 1
	local generation = returnGeneration
	for player, preparation in preparing do
		if preparation ~= "Manual" then
			coordinator:Clear(player)
			preparing[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local partyId = ArenaSessionService.partyIdFor(player)
		if partyId then
			ArenaSessionService.setRoundEligible(player, retainedPartyIds[partyId] == true)
		end
	end
	local groups = partyGroups()
	table.clear(staying)
	for partyId, players in groups do
		task.spawn(sendGroup, partyId, session.matchId, players, generation)
	end
	table.clear(retainedPartyIds)
end

local function returnOptionsFor(player: Player, separateFromParty: boolean?): TeleportOptions
	local options = Instance.new("TeleportOptions")
	local partyId = ArenaSessionService.partyIdFor(player)
	local session = ArenaSessionService.getSnapshot()
	if partyId and session then
		options:SetTeleportData(
			ReturnPayload.build(
				partyId,
				session.matchId,
				ArenaSessionService.partyMemberUserIdsFor(player),
				if separateFromParty then "Separate" else "Party"
			)
		)
	end
	return options
end

local function returnPlayer(player: Player, separateFromParty: boolean): (boolean, string?)
	if player.Parent ~= Players or coordinator:IsTracked(player) or pendingReturn[player] then
		return false, "return_unavailable"
	end
	ArenaSessionService.setRoundEligible(player, false)
	pendingReturn[player] = true
	separatingReturn[player] = if separateFromParty then true else nil
	task.spawn(function()
		local deadline = os.clock() + Loading.TeleportPresentationFallbackSeconds
		while player.Parent == Players and not presentationReady[player.UserId] and os.clock() < deadline do
			task.wait(0.1)
		end
		pendingReturn[player] = nil
		if player.Parent ~= Players or coordinator:IsTracked(player) then
			return
		end
		coordinator:Begin(Env.LobbyPlaceId, { player }, function(_retryPlayers)
			return returnOptionsFor(player, separateFromParty)
		end)
	end)
	return true, nil
end

function ArenaReturnService.returnPlayer(player: Player): (boolean, string?)
	return returnPlayer(player, false)
end

function ArenaReturnService.leavePartyAndReturn(player: Player): (boolean, string?)
	if ArenaSessionService.partyIdFor(player) == nil or #ArenaSessionService.partyMemberUserIdsFor(player) <= 1 then
		return false, "leave_party_unavailable"
	end
	return returnPlayer(player, true)
end

function ArenaReturnService.isSeparatingReturn(player: Player): boolean
	return separatingReturn[player] == true
end

function ArenaReturnService.returnParty(player: Player): (boolean, string?)
	local partyId = ArenaSessionService.partyIdFor(player)
	if partyId == nil then
		return ArenaReturnService.returnPlayer(player)
	end
	local session = ArenaSessionService.getSnapshot()
	local players = ArenaSessionService.partyPlayersFor(player)
	if session == nil or #players == 0 then
		return false, "return_unavailable"
	end
	for _, member in players do
		if coordinator:IsTracked(member) or pendingReturn[member] or preparing[member] then
			return false, "return_unavailable"
		end
	end
	for _, member in players do
		ArenaSessionService.setRoundEligible(member, false)
		pendingReturn[member] = true
	end
	task.spawn(function()
		sendGroup(partyId, session.matchId, players, nil)
		for _, member in players do
			pendingReturn[member] = nil
		end
	end)
	return true, nil
end

function ArenaReturnService.retainParty(player: Player): (boolean, string?)
	local partyId = ArenaSessionService.partyIdFor(player)
	if partyId == nil then
		return true, nil
	end
	retainedPartyIds[partyId] = true
	setPartyEligible(player, true)
	return true, nil
end

function ArenaReturnService.releaseParty(player: Player)
	local partyId = ArenaSessionService.partyIdFor(player)
	if partyId then
		retainedPartyIds[partyId] = nil
		setPartyEligible(player, false)
	end
end

function ArenaReturnService.isPartyRetained(player: Player): boolean
	local partyId = ArenaSessionService.partyIdFor(player)
	return partyId == nil or retainedPartyIds[partyId] == true
end

function ArenaReturnService.onReturnInterrupted(listener: (Player, string) -> ()): () -> ()
	table.insert(interruptedListeners, listener)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(interruptedListeners, listener)
		if index then
			table.remove(interruptedListeners, index)
		end
	end
end

local function handleRequest(player: Player, action: string)
	if action == "Retry" then
		coordinator:Retry(player)
	elseif action == "Stay" and coordinator:Stay(player) then
		local wasSeparating = separatingReturn[player] == true
		separatingReturn[player] = nil
		staying[player] = true
		if wasSeparating then
			ArenaSessionService.setRoundEligible(player, true)
			dispatchInterrupted(player, "stayed")
			return
		end
		local partyId = ArenaSessionService.partyIdFor(player)
		if partyId then
			retainedPartyIds[partyId] = true
		end
		setPartyEligible(player, true)
		dispatchInterrupted(player, "stayed")
	elseif action == "Return" then
		ArenaReturnService.returnPlayer(player)
	end
end

function ArenaReturnService.start()
	if started then
		return
	end
	started = true

	coordinator:SetFailureHandler(function(player, reason)
		warn(`[ArenaReturnService] Could not return {player.Name} to the lobby: {reason}`)
		dispatchInterrupted(player, reason)
	end)
	coordinator:SetStatusHandler(function(player, state, packet)
		if state == "Attempting" or state == "Failed" then
			AnalyticsService.logCustomEvent(
				player,
				if state == "Attempting"
					then AnalyticsConfig.CustomEvents.TeleportAttempt
					else AnalyticsConfig.CustomEvents.TeleportFailed,
				packet.attempt,
				{
					direction = packet.direction,
					maxAttempts = packet.maxAttempts,
					reason = packet.reason,
				}
			)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		staying[player] = nil
		pendingReturn[player] = nil
		separatingReturn[player] = nil
		preparing[player] = nil
		presentationReady[player.UserId] = nil
	end)

	Network.handleProtected("TeleportPresentationReady", { rateLimit = 4 }, function(player)
		presentationReady[player.UserId] = true
		player:SetAttribute("TeleportPresentationReady", true)
	end)

	Network.handleProtected("RequestLobbyReturn", {
		rateLimit = 2,
		validate = function(_player, action)
			return action == "Retry" or action == "Stay" or action == "Return", "invalid_action"
		end,
	}, handleRequest)

	MatchService.onEvent(function(event)
		if event.kind == "MatchReset" then
			returnParties()
		end
	end)
end

return ArenaReturnService
