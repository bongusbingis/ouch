-- Description: Owns party continuation and lobby returns, grouping return intent and checking committed rewards through the shared retry coordinator.

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
local Listeners = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util"):WaitForChild("Listeners")
)

local ArenaReturnService = {}

local started = false
local staying: { [Player]: boolean } = {}
local pendingReturn: { [Player]: boolean } = {}
local separatingReturn: { [Player]: boolean } = {}
local presentationReady: { [number]: boolean } = {}
-- snapshotDispatch = true: handlers disconnect themselves mid-emit (see awaitPlayerPresentation/
-- awaitPreparedPresentation below), so a live iteration would skip the next callback.
local presentationReadySignal = Listeners.new("ArenaReturn.presentationReady", true) :: Listeners.Collection<Player?>

local preparing: { [Player]: number | "Manual" } = {}
local retainedPartyIds: { [string]: boolean } = {}
local interruptedListeners: { (Player, string) -> () } = {}
local returnGeneration = 0
local coordinator = TeleportRetryCoordinator.new("Lobby")

local function awaitPlayerPresentation(player: Player, timeout: number)
	local remaining = math.max(timeout, 0)
	if presentationReady[player.UserId] or player.Parent ~= Players or remaining == 0 then
		return
	end
	local thread = coroutine.running()
	local conn: (() -> ())? = nil
	local timer: thread? = nil
	timer = task.delay(remaining, function()
		if conn then
			conn()
			conn = nil
		end
		task.spawn(thread)
	end)
	conn = presentationReadySignal.add(function(readyPlayer: Player?)
		if readyPlayer == player or player.Parent ~= Players then
			if conn then
				conn()
				conn = nil
			end
			if timer then
				task.cancel(timer)
				timer = nil
			end
			task.spawn(thread)
		end
	end)
	coroutine.yield()
end

local function awaitPreparedPresentation(prepared: { Player }, generation: number?, timeout: number)
	local function allPresented(): boolean
		for _, player in prepared do
			if player.Parent == Players and not presentationReady[player.UserId] then
				return false
			end
		end
		return true
	end

	local remaining = math.max(timeout, 0)
	if allPresented() or remaining == 0 or (generation ~= nil and generation ~= returnGeneration) then
		return
	end

	local thread = coroutine.running()
	local conn: (() -> ())? = nil
	local timer: thread? = nil
	timer = task.delay(remaining, function()
		if conn then
			conn()
			conn = nil
		end
		task.spawn(thread)
	end)
	conn = presentationReadySignal.add(function()
		if allPresented() or (generation ~= nil and generation ~= returnGeneration) then
			if conn then
				conn()
				conn = nil
			end
			if timer then
				task.cancel(timer)
				timer = nil
			end
			task.spawn(thread)
		end
	end)
	coroutine.yield()
end

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

local function rewardPreflight(): TeleportRetryCoordinator.Preflight
	local result = MatchService.resultSnapshot()
	return function(players)
		local committed = result == nil
			or ProgressionService.awaitCommitted(players, result.resultId, PostMatchConfig.RewardCommitTimeoutSeconds)
		return committed, if committed then nil else "rewards_pending"
	end
end

local function sendGroup(
	partyId: string,
	matchId: string,
	players: { Player },
	generation: number?,
	queueOnArrival: boolean?
)
	local memberUserIds = {}
	for _, member in players do
		table.insert(memberUserIds, member.UserId)
	end
	local prepared = coordinator:Prepare(Env.LobbyPlaceId, players, function(_retryPlayers)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(
			ReturnPayload.build(partyId, matchId, memberUserIds, "Party", queueOnArrival, ArenaSessionService.queueId())
		)
		return options
	end, rewardPreflight())
	if #prepared == 0 then
		return
	end
	for _, player in prepared do
		preparing[player] = generation or "Manual"
	end

	awaitPreparedPresentation(prepared, generation, Loading.TeleportPresentationFallbackSeconds)
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
	local canContinue = #MatchService.availableModes() > 0
	if not canContinue then
		table.clear(retainedPartyIds)
	end
	returnGeneration += 1
	presentationReadySignal.emit(nil)
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
			ArenaSessionService.setRoundEligible(
				player,
				canContinue
					and retainedPartyIds[partyId] == true
					and not pendingReturn[player]
					and not coordinator:IsTracked(player)
			)
		elseif not ArenaSessionService.isRoundEligible(player) then
			ArenaReturnService.returnPlayer(player)
		elseif not canContinue then
			ArenaSessionService.setRoundEligible(player, false)
			ArenaReturnService.returnPlayer(player)
		end
	end
	local groups = partyGroups()
	table.clear(staying)
	for partyId, players in groups do
		task.spawn(sendGroup, partyId, assert(session).matchId, players, generation)
	end
	table.clear(retainedPartyIds)
end

local function returnOptionsFor(player: Player, separateFromParty: boolean?, queueOnArrival: boolean?): TeleportOptions
	local options = Instance.new("TeleportOptions")
	local partyId = ArenaSessionService.partyIdFor(player)
	local session = ArenaSessionService.getSnapshot()
	if partyId and session then
		options:SetTeleportData(
			ReturnPayload.build(
				partyId,
				session.matchId,
				ArenaSessionService.partyMemberUserIdsFor(player),
				if separateFromParty then "Separate" else "Party",
				queueOnArrival,
				ArenaSessionService.queueId()
			)
		)
	elseif queueOnArrival then
		local result = MatchService.resultSnapshot()
		assert(result, "[ArenaReturnService] finding players requires a result")
		options:SetTeleportData(
			ReturnPayload.build(
				`solo:{player.UserId}`,
				result.resultId,
				{ player.UserId },
				"Party",
				true,
				ArenaSessionService.queueId()
			)
		)
	end
	return options
end

local function returnPlayer(player: Player, separateFromParty: boolean, queueOnArrival: boolean?): (boolean, string?)
	if player.Parent ~= Players or coordinator:IsTracked(player) or pendingReturn[player] then
		return false, "return_unavailable"
	end
	ArenaSessionService.setRoundEligible(player, false)
	pendingReturn[player] = true
	separatingReturn[player] = if separateFromParty then true else nil
	task.spawn(function()
		local prepared = coordinator:Prepare(Env.LobbyPlaceId, { player }, function(_retryPlayers)
			return returnOptionsFor(player, separateFromParty, queueOnArrival)
		end, rewardPreflight())
		awaitPlayerPresentation(player, Loading.TeleportPresentationFallbackSeconds)
		pendingReturn[player] = nil
		coordinator:StartPrepared(prepared)
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

function ArenaReturnService.returnParty(player: Player, queueOnArrival: boolean?): (boolean, string?)
	local partyId = ArenaSessionService.partyIdFor(player)
	if partyId == nil then
		return returnPlayer(player, false, queueOnArrival)
	end
	local session = ArenaSessionService.getSnapshot()
	local players = {}
	for _, member in ArenaSessionService.partyPlayersFor(player) do
		if not separatingReturn[member] then
			table.insert(players, member)
		end
	end
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
		sendGroup(partyId, session.matchId, players, nil, queueOnArrival)
		for _, member in players do
			pendingReturn[member] = nil
		end
	end)
	return true, nil
end

function ArenaReturnService.retainParty(player: Player): (boolean, string?)
	local partyId = ArenaSessionService.partyIdFor(player)
	setPartyEligible(player, true)
	if #MatchService.availableModes() == 0 then
		setPartyEligible(player, false)
		return false, "not_enough_players"
	end
	if partyId then
		retainedPartyIds[partyId] = true
	end
	return true, nil
end

function ArenaReturnService.releaseParty(player: Player)
	local partyId = ArenaSessionService.partyIdFor(player)
	if partyId then
		retainedPartyIds[partyId] = nil
	end
	setPartyEligible(player, false)
end

function ArenaReturnService.isPartyRetained(player: Player): boolean
	local partyId = ArenaSessionService.partyIdFor(player)
	return ArenaSessionService.isRoundEligible(player)
		and (partyId == nil or retainedPartyIds[partyId] == true)
		and #MatchService.availableModes() > 0
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
		presentationReadySignal.emit(player)
	end)

	Network.handleProtected("TeleportPresentationReady", { rateLimit = 4 }, function(player)
		presentationReady[player.UserId] = true
		player:SetAttribute("TeleportPresentationReady", true)
		presentationReadySignal.emit(player)
	end)

	Network.handleProtected("RequestLobbyReturn", {
		rateLimit = 2,
		validate = function(_player, action)
			return action == "Retry" or action == "Stay" or action == "Return", "invalid_action"
		end,
	}, handleRequest)

	-- MatchEnded retains only players who were round-eligible then. A slow loader
	-- or rejoiner who becomes ready during Results would otherwise be sent to the
	-- lobby at MatchReset, so they keep their party's place in the next round.
	-- A party that chose the lobby left its members ineligible, which this respects.
	ArenaSessionService.onReady(function(player)
		local partyId = ArenaSessionService.partyIdFor(player)
		if
			partyId
			and MatchService.phase() == "Results"
			and ArenaSessionService.isRoundEligible(player)
			and not pendingReturn[player]
			and not coordinator:IsTracked(player)
		then
			retainedPartyIds[partyId] = true
		end
	end)

	MatchService.onEvent(function(event)
		if event.kind == "MatchEnded" then
			table.clear(retainedPartyIds)
			for _, player in Players:GetPlayers() do
				local partyId = ArenaSessionService.partyIdFor(player)
				if partyId and ArenaSessionService.isRoundEligible(player) then
					retainedPartyIds[partyId] = true
				end
			end
		elseif event.kind == "MatchReset" then
			returnParties()
		end
	end)
end

return ArenaReturnService
