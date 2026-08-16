local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)
local Network = require(ReplicatedStorage.Shared.Network)
local Protocol = require(ReplicatedStorage.Shared.Matchmaking.Protocol)

local matchmaking = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Matchmaking")
local MatchmakerService = require(matchmaking.MatchmakerService)
local MatchRepository = require(matchmaking.MatchRepository)
local PartyBus = require(matchmaking.PartyBus)
local PartyRepository = require(matchmaking.PartyRepository)
local PartyService = require(matchmaking.PartyService)
local QueueRepository = require(matchmaking.QueueRepository)
local TeleportCoordinator = require(matchmaking.TeleportCoordinator)

local partyRepository = PartyRepository.new()
local queueRepository = QueueRepository.new()
local matchRepository = MatchRepository.new()
local partyBus = PartyBus.new()
local teleportCoordinator = TeleportCoordinator.new(matchRepository)
local partyService = PartyService.new(partyRepository, queueRepository, matchRepository, partyBus, teleportCoordinator)
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
		[Protocol.Actions.StartMatchmaking] = {
			limit = 2,
			window = 5,
		},
	},
	validate = Protocol.validateRequest,
}, function(player, action, payload)
	return partyService:HandleRequest(player, action, payload)
end)

partyService:Start()

local running = true
task.spawn(function()
	while running do
		task.wait(Config.WorkerPollInterval)
		for mode in partyService:GetLocalQueuedModes() do
			task.spawn(function()
				matchmakerService:Tick(mode)
			end)
		end
	end
end)

game:BindToClose(function()
	running = false
	partyService:Shutdown()
end)
