--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local Loading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Loading"))
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local Matchmaking = Shared:WaitForChild("Game"):WaitForChild("Matchmaking")
local ReturnPayload = require(Matchmaking:WaitForChild("ReturnPayload"))
local TeleportRetryCoordinator = require(Matchmaking:WaitForChild("TeleportRetryCoordinator"))
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local MatchService = require(script.Parent.MatchService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local Env = require(script.Parent.Parent.Env)

local ArenaReturnService = {}

local started = false
local staying: { [Player]: boolean } = {}
local pendingReturn: { [Player]: boolean } = {}
local presentationReady: { [number]: boolean } = {}
local preparing: { [Player]: number } = {}
local returnGeneration = 0
local coordinator = TeleportRetryCoordinator.new("Lobby")

local function partyGroups(): { [string]: { Player } }
	local groups: { [string]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		if staying[player] or coordinator:IsTracked(player) or not ArenaSessionService.isAdmitted(player) then
			continue
		end
		local partyId = ArenaSessionService.partyIdFor(player)
		if partyId == nil then
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

local function sendGroup(partyId: string, matchId: string, players: { Player }, generation: number)
	local memberUserIds = {}
	for _, player in players do
		table.insert(memberUserIds, player.UserId)
	end
	local prepared = coordinator:Prepare(Env.LobbyPlaceId, players, function(_retryPlayers)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(ReturnPayload.build(partyId, matchId, memberUserIds))
		return options
	end)
	if #prepared == 0 then
		return
	end
	for _, player in prepared do
		preparing[player] = generation
	end

	local deadline = os.clock() + Loading.TeleportPresentationFallbackSeconds
	while generation == returnGeneration and os.clock() < deadline do
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
	if generation ~= returnGeneration then
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
	for player in preparing do
		coordinator:Clear(player)
	end
	table.clear(preparing)
	table.clear(staying)
	for partyId, players in partyGroups() do
		task.spawn(sendGroup, partyId, session.matchId, players, generation)
	end
end

local function handleRequest(player: Player, action: string)
	if action == "Retry" then
		coordinator:Retry(player)
	elseif action == "Stay" and coordinator:Stay(player) then
		staying[player] = true
	elseif action == "Return" and not coordinator:IsTracked(player) and not pendingReturn[player] then
		pendingReturn[player] = true
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
				return Instance.new("TeleportOptions")
			end)
		end)
	end
end

function ArenaReturnService.start()
	if started then
		return
	end
	started = true

	coordinator:SetFailureHandler(function(player, reason)
		warn(`[ArenaReturnService] Could not return {player.Name} to the lobby: {reason}`)
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
