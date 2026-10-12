-- Description: Lobby server entry point for matchmaking: constructs the repositories, party bus, party service, one matchmaker per queue, and the teleport coordinator, then starts the matchmaking tick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Protocol"))

local matchmaking = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Matchmaking")
local BanRepository = require(matchmaking.BanRepository)
local MatchmakerService = require(matchmaking.MatchmakerService)
local MatchRepository = require(matchmaking.MatchRepository)
local PartyBus = require(matchmaking.PartyBus)
local PartyRepository = require(matchmaking.PartyRepository)
local PartyService = require(matchmaking.PartyService)
local LobbyGatherCoordinator = require(matchmaking.LobbyGatherCoordinator)
local QueueRepository = require(matchmaking.QueueRepository)
local TeleportCoordinator = require(matchmaking.TeleportCoordinator)
local AnalyticsService = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AnalyticsService"))

local partyRepository = PartyRepository.new()
local matchRepository = MatchRepository.new()
local partyBus = PartyBus.new()
local teleportCoordinator = TeleportCoordinator.new(matchRepository)
local banRepository = BanRepository.new()

local queueRepositories = {}
for _, queueId in Config.QueueOrder do
	queueRepositories[queueId] = QueueRepository.new(queueId)
end

local partyService = PartyService.new(
	partyRepository,
	queueRepositories,
	matchRepository,
	partyBus,
	teleportCoordinator,
	banRepository,
	{
		lobbyGatherCoordinator = LobbyGatherCoordinator.new(partyRepository),
	}
)

local matchmakerServices = {}
for _, queueId in Config.QueueOrder do
	matchmakerServices[queueId] = MatchmakerService.new(
		queueId,
		partyRepository,
		queueRepositories[queueId],
		matchRepository,
		teleportCoordinator,
		function(party, reason, actorUserId)
			partyService:NotifyCommitted(party, reason, actorUserId)
		end
	)
end

teleportCoordinator:SetFailureHandler(function(player)
	partyService:HandleTeleportFailure(player)
end)
teleportCoordinator:SetStatusHandler(function(player, state, packet)
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
partyService:SetQueueChangedHandler(function()
	for _, matchmakerService in matchmakerServices do
		matchmakerService:Tick()
	end
end)

Network.handleProtected("PartyRequest", {
	rateLimit = 8,
	actionRateLimits = {
		default = {
			limit = 6,
			window = 1,
		},
		[Protocol.Actions.JoinByCode] = {
			limit = 2,
			window = 5,
		},
		[Protocol.Actions.KickMember] = {
			limit = 2,
			window = 5,
		},
		[Protocol.Actions.LeaveParty] = {
			limit = 2,
			window = 5,
		},
		[Protocol.Actions.CancelMatchmaking] = {
			limit = 2,
			window = 5,
		},
		[Protocol.Actions.DevSoloPlay] = {
			limit = 1,
			window = 10,
		},
		[Protocol.Actions.StartMatchmaking] = {
			limit = 2,
			window = 5,
		},
		[Protocol.Actions.SetQueue] = {
			limit = 4,
			window = 5,
		},
	},
	validate = Protocol.validateRequest,
}, function(player, action, payload)
	return partyService:HandleRequest(player, action, payload)
end)

Network.handleProtected("TeleportPresentationReady", { rateLimit = 4 }, function(player)
	partyService:HandleTeleportPresentationReady(player)
end)

partyService:Start()

local running = true
task.spawn(function()
	while running do
		task.wait(Config.WorkerPollInterval)
		for _, queueId in Config.QueueOrder do
			if partyService:HasLocalQueuedParty(queueId) then
				local matchmakerService = matchmakerServices[queueId]
				task.spawn(function()
					matchmakerService:Tick()
				end)
			end
		end
	end
end)

game:BindToClose(function()
	running = false
	partyService:Shutdown()
end)
