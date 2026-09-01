-- Name: TeleportRetryCoordinator.luau
-- Author: Jack C.
-- Description: Shared teleport driver that classifies failures, retries the transient ones with backoff, reports status to the client, and exposes retry and stay actions after a final failure.
-- Created: 2026-08-24

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Loading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Loading"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

export type Direction = "Arena" | "Lobby"
export type OptionsFactory = (players: { Player }) -> TeleportOptions
export type FailureHandler = (player: Player, reason: string) -> ()
export type StatusHandler = (player: Player, state: string, packet: { [string]: any }) -> ()

type Batch = {
	userIds: { number },
	retryAt: number,
	retryRevision: number,
}

type State = {
	active: boolean,
	failed: boolean,
	pendingRetry: boolean,
	attempt: number,
	generation: number,
	placeId: number,
	optionsFactory: OptionsFactory,
	batch: Batch,
}

local TeleportRetryCoordinator = {}
TeleportRetryCoordinator.__index = TeleportRetryCoordinator

local RETRYABLE_RESULTS = {
	Failure = true,
	Flooded = true,
	GameFull = true,
}

local function reasonName(result: Enum.TeleportResult): string
	return result.Name
end

function TeleportRetryCoordinator.new(direction: Direction)
	local self = setmetatable({
		_direction = direction,
		_states = {} :: { [number]: State },
		_failureHandler = nil :: FailureHandler?,
		_statusHandler = nil :: StatusHandler?,
		_destroyed = false,
		_connections = {} :: { RBXScriptConnection },
	}, TeleportRetryCoordinator)

	table.insert(
		self._connections,
		TeleportService.TeleportInitFailed:Connect(function(player, result, _message, placeId)
			self:_handleFailure(player, result, placeId)
		end)
	)
	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player)
			self:Clear(player)
		end)
	)

	return self
end

function TeleportRetryCoordinator:SetFailureHandler(handler: FailureHandler?)
	self._failureHandler = handler
end

function TeleportRetryCoordinator:SetStatusHandler(handler: StatusHandler?)
	self._statusHandler = handler
end

function TeleportRetryCoordinator:_sendStatus(player: Player, stateName: string, extra: any?)
	if player.Parent ~= Players then
		return
	end
	local state = self._states[player.UserId]
	local packet: { [string]: any } = {
		direction = self._direction,
		state = stateName,
		attempt = if state then state.attempt else 0,
		maxAttempts = Loading.TeleportRetryAttempts,
	}
	if extra then
		for key, value in extra do
			packet[key] = value
		end
	end
	Network.fire("TeleportStatus", player, packet)
	if self._statusHandler then
		local ok, err = pcall(self._statusHandler, player, stateName, packet)
		if not ok then
			warn(`[TeleportRetryCoordinator] status handler failed: {err}`)
		end
	end
end

function TeleportRetryCoordinator:IsTeleporting(player: Player): boolean
	local state = self._states[player.UserId]
	return state ~= nil and state.active
end

function TeleportRetryCoordinator:IsTracked(player: Player): boolean
	return self._states[player.UserId] ~= nil
end

function TeleportRetryCoordinator:CanRetry(player: Player): boolean
	local state = self._states[player.UserId]
	return state ~= nil and state.failed
end

function TeleportRetryCoordinator:Clear(player: Player)
	local state = self._states[player.UserId]
	if state then
		state.active = false
		state.generation += 1
		self._states[player.UserId] = nil
	end
end

function TeleportRetryCoordinator:_fail(player: Player, reason: string)
	local state = self._states[player.UserId]
	if state == nil then
		return
	end
	state.active = false
	state.failed = true
	state.pendingRetry = false
	state.generation += 1
	self:_sendStatus(player, "Failed", { reason = reason })
	if self._failureHandler then
		self._failureHandler(player, reason)
	end
end

function TeleportRetryCoordinator:_teleport(players: { Player }): (boolean, any?)
	if self._destroyed or #players == 0 then
		return false, "cancelled"
	end

	local firstState = self._states[players[1].UserId]
	if firstState == nil then
		return false, "cancelled"
	end

	local options: TeleportOptions? = nil
	local success, teleportError = pcall(function()
		options = firstState.optionsFactory(players)
		TeleportService:TeleportAsync(firstState.placeId, players, options :: TeleportOptions)
	end)
	if options then
		options:Destroy()
	end

	if not success then
		for _, player in players do
			self:_handleFailure(player, Enum.TeleportResult.Failure, firstState.placeId)
		end
	end
	return success, teleportError
end

function TeleportRetryCoordinator:_handleFailure(player: Player, result: Enum.TeleportResult, placeId: number)
	local state = self._states[player.UserId]
	if self._destroyed or state == nil or not state.active or state.pendingRetry or state.placeId ~= placeId then
		return
	end

	if not RETRYABLE_RESULTS[result.Name] or state.attempt >= Loading.TeleportRetryAttempts then
		self:_fail(player, reasonName(result))
		return
	end

	state.attempt += 1
	state.pendingRetry = true
	state.generation += 1
	local delaySeconds = if result == Enum.TeleportResult.Flooded
		then Loading.TeleportFloodedDelaySeconds
		else Loading.TeleportRetryDelaySeconds
	local retryAt = Workspace:GetServerTimeNow() + delaySeconds
	self:_sendStatus(player, "Retrying", {
		retryAt = retryAt,
		reason = reasonName(result),
	})

	local batch = state.batch
	batch.retryAt = math.max(batch.retryAt, retryAt)
	batch.retryRevision += 1
	local retryRevision = batch.retryRevision
	task.delay(math.max(batch.retryAt - Workspace:GetServerTimeNow(), 0), function()
		if self._destroyed or batch.retryRevision ~= retryRevision then
			return
		end
		batch.retryAt = 0
		local retryPlayers = {}
		for _, userId in batch.userIds do
			local current = self._states[userId]
			local retryPlayer = Players:GetPlayerByUserId(userId)
			if current and current.batch == batch and current.active and current.pendingRetry and retryPlayer then
				current.pendingRetry = false
				self:_sendStatus(retryPlayer, "Attempting")
				table.insert(retryPlayers, retryPlayer)
			end
		end
		self:_teleport(retryPlayers)
	end)
end

function TeleportRetryCoordinator:Prepare(
	placeId: number,
	players: { Player },
	optionsFactory: OptionsFactory
): { Player }
	local pending = {}
	local batch: Batch = {
		userIds = {},
		retryAt = 0,
		retryRevision = 0,
	}
	for _, player in players do
		if player.Parent == Players and not self:IsTracked(player) then
			self._states[player.UserId] = {
				active = true,
				failed = false,
				pendingRetry = false,
				attempt = 1,
				generation = 1,
				placeId = placeId,
				optionsFactory = optionsFactory,
				batch = batch,
			}
			table.insert(batch.userIds, player.UserId)
			table.insert(pending, player)
			self:_sendStatus(player, "Attempting")
		end
	end
	return pending
end

function TeleportRetryCoordinator:StartPrepared(players: { Player }): (boolean, any?)
	local pending = {}
	for _, player in players do
		local state = self._states[player.UserId]
		if state and state.active and not state.pendingRetry and player.Parent == Players then
			table.insert(pending, player)
		end
	end
	if #pending == 0 then
		return true
	end
	return self:_teleport(pending)
end

function TeleportRetryCoordinator:Begin(
	placeId: number,
	players: { Player },
	optionsFactory: OptionsFactory
): (boolean, any?)
	return self:StartPrepared(self:Prepare(placeId, players, optionsFactory))
end

function TeleportRetryCoordinator:Retry(player: Player): boolean
	local state = self._states[player.UserId]
	if state == nil or not state.failed or player.Parent ~= Players then
		return false
	end
	local batch = state.batch
	batch.retryRevision += 1
	batch.retryAt = 0
	local retryPlayers = {}
	for _, userId in batch.userIds do
		local current = self._states[userId]
		local retryPlayer = Players:GetPlayerByUserId(userId)
		if current and current.batch == batch and retryPlayer then
			current.active = true
			current.failed = false
			current.pendingRetry = false
			current.attempt = 1
			current.generation += 1
			self:_sendStatus(retryPlayer, "Attempting")
			table.insert(retryPlayers, retryPlayer)
		end
	end
	self:_teleport(retryPlayers)
	return true
end

function TeleportRetryCoordinator:Stay(player: Player): boolean
	local state = self._states[player.UserId]
	if state == nil or not state.failed then
		return false
	end
	local batch = state.batch
	batch.retryRevision += 1
	batch.retryAt = 0
	for _, userId in batch.userIds do
		local current = self._states[userId]
		local batchPlayer = Players:GetPlayerByUserId(userId)
		if current and current.batch == batch and batchPlayer then
			self:_sendStatus(batchPlayer, "Complete", { reason = "Stayed" })
			self:Clear(batchPlayer)
		end
	end
	return true
end

function TeleportRetryCoordinator:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, state in self._states do
		state.active = false
		state.generation += 1
	end
	table.clear(self._states)
end

return TeleportRetryCoordinator
