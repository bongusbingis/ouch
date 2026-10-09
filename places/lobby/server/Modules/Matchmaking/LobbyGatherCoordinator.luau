-- Description: Best-effort co-location in the leader's public lobby. PartyBus remains active; no chat is relayed.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)
local PartyModel = require(script.Parent.PartyModel)

local LobbyGatherCoordinator = {}
LobbyGatherCoordinator.__index = LobbyGatherCoordinator

function LobbyGatherCoordinator.new(repository, dependencies)
	local deps = dependencies or {}
	local self = setmetatable({
		_repository = repository,
		_players = deps.players or Players,
		_teleportService = deps.teleportService or TeleportService,
		_placeId = deps.placeId or game.PlaceId,
		_gameId = deps.gameId or game.GameId,
		_jobId = deps.jobId or game.JobId,
		_now = deps.now or os.time,
		_enabled = if deps.enabled ~= nil then deps.enabled else not RunService:IsStudio(),
		_pending = {},
		_attempted = {},
		_checking = {},
		_destroyed = false,
	}, LobbyGatherCoordinator)
	self._connection = self._teleportService.TeleportInitFailed:Connect(
		function(player, _result, _message, placeId, options)
			local ok, data = pcall(function()
				return options:GetTeleportData()
			end)
			local pending = self._pending[player.UserId]
			if
				pending
				and placeId == self._placeId
				and ok
				and type(data) == "table"
				and data.lobbyGatherToken == pending.token
			then
				self._pending[player.UserId] = nil
			end
		end
	)
	return self
end

function LobbyGatherCoordinator:IsGathering(player, partyId)
	local pending = self._pending[player.UserId]
	return pending ~= nil and (partyId == nil or pending.partyId == partyId)
end

function LobbyGatherCoordinator:_target(party)
	if
		not party
		or party.phase ~= "Lobby"
		or #party.members < 2
		or not PartyModel.hasMember(party, party.leaderUserId)
	then
		return nil
	end
	local presence = self._repository:GetUserPresence(party.leaderUserId)
	if
		not presence
		or presence.partyId ~= party.partyId
		or presence.placeId ~= self._placeId
		or presence.publicServer ~= true
		or type(presence.jobId) ~= "string"
		or presence.jobId == ""
		or type(presence.refreshedAt) ~= "number"
		or presence.refreshedAt > self._now()
		or self._now() - presence.refreshedAt >= Config.PresenceLifetime
	then
		return nil
	end
	return presence.jobId
end

-- MemoryStore checks yield. Recheck attachment and authoritative phase before dispatch.
function LobbyGatherCoordinator:Consider(player, partyId, isAttached, isArenaTeleporting)
	local userId = player.UserId
	if
		not self._enabled
		or self._destroyed
		or self._jobId == ""
		or self._checking[userId]
		or self:IsGathering(player)
	then
		return
	end
	self._checking[userId] = true
	local ok, message = xpcall(function()
		local party = self._repository:GetParty(partyId)
		if not party or not PartyModel.hasMember(party, userId) or party.leaderUserId == userId then
			return
		end
		local target = self:_target(party)
		if not target or target == self._jobId then
			return
		end
		local key = partyId .. ":" .. target
		self._attempted[userId] = self._attempted[userId] or {}
		if self._attempted[userId][key] then
			return
		end
		party = self._repository:GetParty(partyId)
		if
			not party
			or party.phase ~= "Lobby"
			or not PartyModel.hasMember(party, userId)
			or self._destroyed
			or player.Parent ~= self._players
			or not isAttached()
			or isArenaTeleporting()
			or self:IsGathering(player)
		then
			return
		end
		if
			self:_target(party) ~= target
			or self._destroyed
			or player.Parent ~= self._players
			or not isAttached()
			or isArenaTeleporting()
		then
			return
		end
		local options = Instance.new("TeleportOptions")
		local pending = { partyId = partyId, targetJobId = target, token = HttpService:GenerateGUID(false) }
		options.ServerInstanceId = target
		options:SetTeleportData({
			lobbyGatherVersion = 1,
			partyId = partyId,
			targetJobId = target,
			lobbyGatherToken = pending.token,
		})
		self._attempted[userId][key] = true
		self._pending[userId] = pending
		local dispatched = pcall(function()
			self._teleportService:TeleportAsync(self._placeId, { player }, options)
		end)
		options:Destroy()
		if not dispatched and self._pending[userId] == pending then
			self._pending[userId] = nil
		end
		-- Elapsed time neither cancels an in-flight teleport nor establishes failure.
	end, debug.traceback)
	self._checking[userId] = nil
	if not ok then
		warn("[LobbyGatherCoordinator] " .. tostring(message))
	end
end

-- TeleportData is only a hint: membership AND the current presence index authorize restoration.
-- Cloud errors are handled without letting initialization destroy the existing party.
function LobbyGatherCoordinator:RestoreArrival(player, attach)
	local joinData = player:GetJoinData()
	local data = joinData.TeleportData
	if
		joinData.SourcePlaceId ~= self._placeId
		or joinData.SourceGameId ~= self._gameId
		or type(data) ~= "table"
		or data.lobbyGatherVersion ~= 1
		or type(data.partyId) ~= "string"
		or #data.partyId > 100
		or type(data.targetJobId) ~= "string"
		or #data.targetJobId > 100
	then
		return false
	end
	local presence, presenceError = self._repository:GetUserPresence(player.UserId)
	if presenceError then
		return true, presenceError
	end
	if not presence or presence.partyId ~= data.partyId then
		return false
	end
	local party, partyError = self._repository:GetParty(data.partyId)
	if partyError then
		return true, partyError
	end
	if not party or not PartyModel.hasMember(party, player.UserId) then
		return false
	end
	local indexed, indexError = self._repository:SetUserParty(player.UserId, party.partyId)
	if not indexed then
		return true, indexError or "presence_unavailable"
	end
	if player.Parent == self._players then
		-- A vanished target can route to another public server. Suppress bouncing back to that target.
		self._attempted[player.UserId] = { [data.partyId .. ":" .. data.targetJobId] = true }
		attach(party)
	end
	return true
end

function LobbyGatherCoordinator:Clear(player)
	self._pending[player.UserId] = nil
	self._attempted[player.UserId] = nil
end

function LobbyGatherCoordinator:Destroy()
	self._destroyed = true
	self._connection:Disconnect()
	table.clear(self._pending)
	table.clear(self._attempted)
end

return LobbyGatherCoordinator
