local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)
local CloudRetry = require(script.Parent.CloudRetry)

local TeleportCoordinator = {}
TeleportCoordinator.__index = TeleportCoordinator

function TeleportCoordinator.new(matchRepository)
	local self = setmetatable({
		_matchRepository = matchRepository,
		_states = {},
		_failureHandler = nil,
	}, TeleportCoordinator)

	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		self:_handleInitFailure(player, result, message, placeId, options)
	end)

	return self
end

function TeleportCoordinator:SetFailureHandler(handler)
	self._failureHandler = handler
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
	local state = self._states[player.UserId]
	return state ~= nil and state.active == true
end

function TeleportCoordinator:Clear(player)
	self._states[player.UserId] = nil
end

function TeleportCoordinator:_fail(player, message)
	self._states[player.UserId] = nil
	if self._failureHandler then
		self._failureHandler(player, message)
	end
end

function TeleportCoordinator:_handleInitFailure(player, result, message, placeId, options)
	local state = self._states[player.UserId]
	if not state or not state.active then
		return
	end

	if state.attempts >= Config.TeleportRetryAttempts then
		self:_fail(player, message)
		return
	end

	state.attempts += 1
	local delay = result == Enum.TeleportResult.Flooded and Config.TeleportFloodedDelay or Config.TeleportRetryDelay

	task.delay(delay, function()
		if player.Parent ~= Players then
			return
		end

		local success, retryError = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player }, options)
		if not success then
			self:_handleInitFailure(player, Enum.TeleportResult.Failure, retryError, placeId, options)
		end
	end)
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
			self._states[player.UserId] = {
				active = true,
				attempts = 1,
				matchId = matchId,
			}
		end
	end

	if #players == 0 then
		return true
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = matchRecord.reservedServerAccessCode
	options:SetTeleportData({
		schemaVersion = Config.ProtocolVersion,
		matchId = matchRecord.matchId,
		mode = matchRecord.mode,
		mapKey = matchRecord.mapKey,
	})

	local success, teleportError =
		pcall(TeleportService.TeleportAsync, TeleportService, matchRecord.arenaPlaceId, players, options)
	if not success then
		for _, player in players do
			self:_handleInitFailure(
				player,
				Enum.TeleportResult.Failure,
				teleportError,
				matchRecord.arenaPlaceId,
				options
			)
		end
	end

	return success, teleportError
end

return TeleportCoordinator
