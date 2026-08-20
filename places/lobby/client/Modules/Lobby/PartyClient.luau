--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Protocol"))
local PartyStore = require(script.Parent.PartyStore)

local PartyClient = {}
PartyClient.__index = PartyClient

PartyClient.ErrorMessages = {
	arena_not_configured = "MATCH PLACE IS NOT CONFIGURED",
	busy = "PLEASE WAIT...",
	internal_error = "PARTY SERVICE UNAVAILABLE",
	invalid_args = "INVALID PARTY REQUEST",
	invalid_code = "PARTY CODE NOT FOUND",
	invalid_request = "INVALID PARTY REQUEST",
	invite_unavailable = "INVITES ARE UNAVAILABLE",
	match_forming = "MATCH IS ALREADY FORMING",
	matchmaking_unavailable = "MATCHMAKING COULD NOT BEGIN",
	not_party_leader = "ONLY THE PARTY LEADER CAN DO THAT",
	party_full = "THAT PARTY IS FULL",
	party_not_found = "PARTY NOT FOUND",
	party_not_ready = "PARTY IS STILL LOADING",
	rate_limited = "TOO MANY REQUESTS",
	teleport_failed = "TELEPORT FAILED - TRY AGAIN",
}

PartyClient.JoinCodeErrorMessages = {
	invalid_code = "PARTY CODE NOT FOUND",
	party_full = "THAT PARTY IS FULL",
	party_not_found = "PARTY CODE NOT FOUND",
}

function PartyClient.new()
	local self = setmetatable({
		_player = Players.LocalPlayer,
		_store = PartyStore.new(),
		_busy = false,
		_started = false,
		_destroyed = false,
		_generation = 0,
		_listeners = {},
		_errorListeners = {},
		_nextListenerId = 0,
		_connections = {},
	}, PartyClient)
	return self
end

function PartyClient:getSnapshot()
	return self._store:GetSnapshot()
end

function PartyClient:isBusy(): boolean
	return self._busy
end

function PartyClient:_emit(snapshot, previous, reason)
	for _, callback in self._listeners do
		local ok, err = pcall(callback, snapshot, previous, reason)
		if not ok then
			warn(`[PartyClient] subscriber failed: {err}`)
		end
	end
end

function PartyClient:_emitError(errorCode: string)
	for _, callback in self._errorListeners do
		local ok, err = pcall(callback, errorCode)
		if not ok then
			warn(`[PartyClient] error subscriber failed: {err}`)
		end
	end
end

function PartyClient:subscribe(callback)
	self._nextListenerId += 1
	local id = self._nextListenerId
	self._listeners[id] = callback
	callback(self:getSnapshot(), nil, "Subscribed")
	return function()
		self._listeners[id] = nil
	end
end

function PartyClient:subscribeErrors(callback)
	self._nextListenerId += 1
	local id = self._nextListenerId
	self._errorListeners[id] = callback
	return function()
		self._errorListeners[id] = nil
	end
end

function PartyClient:_setBusy(busy: boolean)
	if self._busy == busy then
		return
	end
	self._busy = busy
	self:_emit(self:getSnapshot(), self:getSnapshot(), "BusyChanged")
end

function PartyClient:request(action: string, payload: any?, reportError: boolean?)
	if self._busy or self._destroyed then
		return nil, "busy"
	end
	self:_setBusy(true)
	local success, response, networkError = pcall(Network.call, "PartyRequest", action, payload)
	self:_setBusy(false)
	if self._destroyed then
		return nil, "internal_error"
	end
	if not success then
		if reportError ~= false then
			self:_emitError("internal_error")
		end
		return nil, "internal_error"
	end
	if not response or not response.ok then
		local errorCode = if response then response.error else networkError or "internal_error"
		if reportError ~= false then
			self:_emitError(errorCode)
		end
		return response, errorCode
	end
	if response.snapshot then
		self._store:ApplySnapshot(response.snapshot, action)
	end
	return response, nil
end

function PartyClient:joinByCode(code: string)
	return self:request(Protocol.Actions.JoinByCode, { code = code }, false)
end

function PartyClient:kick(targetUserId: number)
	return self:request(Protocol.Actions.KickMember, { targetUserId = targetUserId })
end

function PartyClient:toggleMatchmaking()
	local snapshot = self:getSnapshot()
	if snapshot == nil or snapshot.leaderUserId ~= self._player.UserId then
		return nil, "not_party_leader"
	end
	if snapshot.phase == "Lobby" then
		return self:request(Protocol.Actions.StartMatchmaking, nil)
	elseif snapshot.phase == "Queued" then
		return self:request(Protocol.Actions.CancelMatchmaking, nil)
	end
	return nil, "match_forming"
end

function PartyClient:devSoloPlay()
	return self:request(Protocol.Actions.DevSoloPlay, nil, false)
end

function PartyClient:promptInvite()
	local snapshot = self:getSnapshot()
	if snapshot == nil then
		self:_emitError("party_not_ready")
		return false
	end
	local success, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, self._player)
	if not success or not canInvite then
		self:_emitError("invite_unavailable")
		return false
	end
	local options = Instance.new("ExperienceInviteOptions")
	options.LaunchData = Protocol.inviteData(snapshot.partyId, self._player.UserId)
	local prompted, promptError = pcall(SocialService.PromptGameInvite, SocialService, self._player, options)
	options:Destroy()
	if not prompted then
		warn(`[PartyClient] invite prompt failed: {promptError}`)
		self:_emitError("invite_unavailable")
		return false
	end
	return true
end

function PartyClient:start()
	if self._started then
		return
	end
	self._started = true
	table.insert(
		self._connections,
		self._store:Subscribe(function(snapshot, previous, reason)
			self:_emit(snapshot, previous, reason)
		end)
	)
	table.insert(
		self._connections,
		Network.on("PartyPacket", function(packet)
			if self._destroyed or typeof(packet) ~= "table" then
				return
			end
			if packet.kind == "Snapshot" then
				self._store:ApplySnapshot(packet.snapshot, packet.reason)
			elseif packet.kind == "Error" then
				self:_emitError(packet.error)
			end
		end)
	)

	self._generation += 1
	local generation = self._generation
	task.spawn(function()
		local lastError = "internal_error"
		for _ = 1, 10 do
			if self._destroyed or generation ~= self._generation or self:getSnapshot() ~= nil then
				return
			end
			local response, errorCode = self:request(Protocol.Actions.GetSnapshot, nil, false)
			if response and response.ok then
				return
			end
			lastError = errorCode or lastError
			task.wait(1)
		end
		if not self._destroyed and generation == self._generation and self:getSnapshot() == nil then
			self:_emitError(if lastError == "party_not_ready" then "internal_error" else lastError)
		end
	end)
end

function PartyClient:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._generation += 1
	for _, disconnect in self._connections do
		if typeof(disconnect) == "RBXScriptConnection" then
			disconnect:Disconnect()
		else
			disconnect()
		end
	end
	table.clear(self._connections)
	table.clear(self._listeners)
	table.clear(self._errorListeners)
end

return PartyClient
