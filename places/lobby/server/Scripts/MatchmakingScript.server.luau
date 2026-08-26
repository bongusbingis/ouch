-- Name: MatchmakingScript.server.luau
-- Author: Jack C.
-- Description: Lobby server entry point for matchmaking: constructs the repositories, party bus, party service, matchmaker, and teleport coordinator and starts the matchmaking tick.
-- Created: 2026-08-15

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsConfig = require(ReplicatedStorage.Config.Analytics)
local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)
local Network = require(ReplicatedStorage.Shared.Network)
local Protocol = require(ReplicatedStorage.Shared.Matchmaking.Protocol)

local matchmaking = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Matchmaking")
local BanRepository = require(matchmaking.BanRepository)
local MatchmakerService = require(matchmaking.MatchmakerService)
local MatchRepository = require(matchmaking.MatchRepository)
local PartyBus = require(matchmaking.PartyBus)
local PartyRepository = require(matchmaking.PartyRepository)
local PartyService = require(matchmaking.PartyService)
local QueueRepository = require(matchmaking.QueueRepository)
local TeleportCoordinator = require(matchmaking.TeleportCoordinator)
local AnalyticsService = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AnalyticsService"))

local partyRepository = PartyRepository.new()
local queueRepository = QueueRepository.new()
local matchRepository = MatchRepository.new()
local partyBus = PartyBus.new()
local teleportCoordinator = TeleportCoordinator.new(matchRepository)
local banRepository = BanRepository.new()
local partyService =
	PartyService.new(partyRepository, queueRepository, matchRepository, partyBus, teleportCoordinator, banRepository)
local matchmakerService = MatchmakerService.new(
	partyRepository,
	queueRepository,
	matchRepository,
	teleportCoordinator,
	function(party, reason, actorUserId)
		partyService:NotifyCommitted(party, reason, actorUserId)
	end
)

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
	matchmakerService:Tick()
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
		[Protocol.Actions.DevSoloPlay] = {
			limit = 1,
			window = 10,
		},
		[Protocol.Actions.StartMatchmaking] = {
			limit = 2,
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
		if partyService:HasLocalQueuedParty() then
			task.spawn(function()
				matchmakerService:Tick()
			end)
		end
	end
end)

game:BindToClose(function()
	running = false
	partyService:Shutdown()
end)
