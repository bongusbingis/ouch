-- Description: Reserves an arena server for a matched party and teleports its members with the built payload, reporting status and delegating retries to the shared retry coordinator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local TeleportPayload = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("TeleportPayload")
)
local TeleportRetryCoordinator = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("TeleportRetryCoordinator")
)
local CloudRetry = require(script.Parent.CloudRetry)

local TeleportCoordinator = {}
TeleportCoordinator.__index = TeleportCoordinator

function TeleportCoordinator.new(matchRepository)
	local self = setmetatable({
		_matchRepository = matchRepository,
		_retry = TeleportRetryCoordinator.new("Arena"),
	}, TeleportCoordinator)

	return self
end

function TeleportCoordinator:SetFailureHandler(handler)
	self._retry:SetFailureHandler(function(player, reason)
		self._retry:Clear(player)
		handler(player, reason)
	end)
end

function TeleportCoordinator:SetStatusHandler(handler)
	self._retry:SetStatusHandler(handler)
end

function TeleportCoordinator:ReserveServer()
	if Config.ArenaPlaceId <= 0 then
		return nil, "arena_not_configured"
	end

	local success, accessCode = CloudRetry.call("TeleportCoordinator.ReserveServer", function()
		return TeleportService:ReserveServerAsync(Config.ArenaPlaceId)
	end)
	if not success then
		return nil, accessCode
	end

	return accessCode
end

function TeleportCoordinator:IsTeleporting(player)
	return self._retry:IsTeleporting(player)
end

function TeleportCoordinator:Clear(player)
	self._retry:Clear(player)
end

function TeleportCoordinator:TeleportParty(matchId, partyId, partyPlayers)
	local matchRecord, matchError = self._matchRepository:GetMatch(matchId)
	if not matchRecord then
		return false, matchError or "match_not_found"
	end
	if not self._matchRepository:ContainsParty(matchRecord, partyId) then
		return false, "party_not_in_match"
	end

	local expected = {}
	for _, userId in matchRecord.expectedUserIds do
		expected[userId] = true
	end

	local players = {}
	for _, player in partyPlayers do
		if expected[player.UserId] and not self:IsTeleporting(player) then
			table.insert(players, player)
		end
	end

	if #players == 0 then
		return true
	end

	return self._retry:Begin(matchRecord.arenaPlaceId, players, function(_retryPlayers)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = matchRecord.reservedServerAccessCode
		options:SetTeleportData(TeleportPayload.build(matchRecord, partyId))
		return options
	end)
end

function TeleportCoordinator:Destroy()
	self._retry:Destroy()
end

return TeleportCoordinator
