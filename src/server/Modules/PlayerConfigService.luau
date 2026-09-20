-- Description: Resolves complete per-player ConfigService candidates and projects accepted values onto Player-owned folders.
--!strict

local ConfigService = game:GetService("ConfigService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfigResolver = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Config")
		:WaitForChild("PlayerConfigResolver")
)

export type Schema = {
	FolderName: string,
	RevisionAttribute: string,
	Entries: { PlayerConfigResolver.Entry },
}

type PlayerState = {
	snapshot: any?,
	connection: RBXScriptConnection?,
	retryPending: boolean,
	defaultsProjected: boolean,
	serial: number,
	observer: number,
	lastFailure: string?,
}

type Projection = { schema: Schema, resolved: { [string]: any }, folder: Folder?, revision: number }

local PlayerConfigService = {}
local started = false
local schemas: { Schema } = {}
local retrySeconds = 30
local states: { [Player]: PlayerState } = {}

local function current(player: Player, state: PlayerState, serial: number): boolean
	return player.Parent == Players and states[player] == state and state.serial == serial
end

local function reportFailure(player: Player, state: PlayerState, reason: string)
	if state.lastFailure ~= reason then
		warn(
			`[PlayerConfigService] player.UserId={player.UserId}: {reason}; check authored ConfigService values or service availability; retrying in {retrySeconds}s`
		)
		state.lastFailure = reason
	end
end

local function reportRecovery(player: Player, state: PlayerState)
	if state.lastFailure ~= nil then
		warn(
			`[PlayerConfigService] player.UserId={player.UserId}: ConfigService recovered; accepted complete player snapshot`
		)
		state.lastFailure = nil
	end
end

local function disconnect(state: PlayerState)
	state.observer += 1
	if state.connection ~= nil then
		state.connection:Disconnect()
		state.connection = nil
	end
	state.snapshot = nil
end

local function preflight(player: Player, schema: Schema, resolved: { [string]: any }): (boolean, string?, Projection?)
	local existing = player:FindFirstChild(schema.FolderName)
	if existing ~= nil and not existing:IsA("Folder") then
		return false, `{existing:GetFullName()}: expected Folder; received {existing.ClassName}`, nil
	end
	local folder = existing :: Folder?
	local revision = 0
	if folder ~= nil then
		local rawRevision = folder:GetAttribute(schema.RevisionAttribute)
		if
			typeof(rawRevision) ~= "number"
			or rawRevision ~= rawRevision
			or rawRevision < 0
			or rawRevision == math.huge
		then
			return false,
				`{folder:GetFullName()}.{schema.RevisionAttribute}: expected finite nonnegative revision; received {tostring(
					rawRevision
				)}`,
				nil
		end
		revision = rawRevision
		for _, entry in schema.Entries do
			local child = folder:FindFirstChild(entry.Key)
			local className = if entry.Type == "boolean" then "BoolValue" else "NumberValue"
			if child ~= nil and not child:IsA(className) then
				return false, `{child:GetFullName()}: expected {className}; received {child.ClassName}`, nil
			end
		end
	end
	return true, nil, { schema = schema, resolved = resolved, folder = folder, revision = revision }
end

local function writeProjection(player: Player, projection: Projection): (boolean, string?)
	local schema = projection.schema
	local ok, err = pcall(function()
		local folder = projection.folder
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = schema.FolderName
			folder:SetAttribute(schema.RevisionAttribute, 0)
			folder.Parent = player
		end
		local target = folder :: Folder
		for _, entry in schema.Entries do
			local child = target:FindFirstChild(entry.Key)
			if child == nil then
				child = Instance.new(if entry.Type == "boolean" then "BoolValue" else "NumberValue")
				child.Name = entry.Key
				child.Parent = target
			end
			(child :: any).Value = projection.resolved[entry.Key]
		end
		target:SetAttribute(schema.RevisionAttribute, projection.revision + 1)
	end)
	if not ok then
		return false, `{player:GetFullName()}.{schema.FolderName}: projection write failed: {err}`
	end
	return true, nil
end

local function projectCandidate(player: Player, resolvedBySchema: { [Schema]: { [string]: any } }): (boolean, string?)
	local projections: { Projection } = {}
	for _, schema in schemas do
		local ok, reason, projection = preflight(player, schema, resolvedBySchema[schema])
		if not ok or projection == nil then
			return false, reason
		end
		table.insert(projections, projection)
	end
	for _, projection in projections do
		local ok, reason = writeProjection(player, projection)
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

local function defaults(): (boolean, string?, { [Schema]: { [string]: any } }?)
	local bySchema: { [Schema]: { [string]: any } } = {}
	for _, schema in schemas do
		local ok, reason, resolved = PlayerConfigResolver.resolve(schema.Entries, {})
		if not ok or resolved == nil then
			return false, `{schema.FolderName}.{reason}`, nil
		end
		bySchema[schema] = resolved
	end
	return true, nil, bySchema
end

local function readCandidate(
	player: Player,
	state: PlayerState,
	snapshot: any,
	serial: number
): (boolean, string?, { [Schema]: { [string]: any } }?)
	local bySchema: { [Schema]: { [string]: any } } = {}
	for _, schema in schemas do
		local rawValues: { [string]: any } = {}
		for _, entry in schema.Entries do
			local ok, value = pcall(snapshot.GetValue, snapshot, entry.Key)
			if not current(player, state, serial) then
				return false, "stale snapshot callback", nil
			end
			if not ok then
				return false,
					`ConfigService:GetConfigForPlayerAsync(player.UserId={player.UserId}).GetValue("{entry.Key}") failed: {value}`,
					nil
			end
			rawValues[entry.Key] = value
		end
		local ok, reason, resolved = PlayerConfigResolver.resolve(schema.Entries, rawValues)
		if not ok or resolved == nil then
			local key = if reason then string.match(reason, "^([^:]+):") else "unknown"
			return false,
				`ConfigService:GetConfigForPlayerAsync(player.UserId={player.UserId}).GetValue("{key}") in {schema.FolderName}: {reason}; correct the authored value`,
				nil
		end
		bySchema[schema] = resolved
	end
	return true, nil, bySchema
end

local acquire: (Player, PlayerState) -> ()

local function scheduleRetry(player: Player, state: PlayerState)
	if state.retryPending or states[player] ~= state or player.Parent ~= Players then
		return
	end
	state.retryPending = true
	task.delay(retrySeconds, function()
		if states[player] ~= state or player.Parent ~= Players then
			return
		end
		state.retryPending = false
		acquire(player, state)
	end)
end

local function fail(player: Player, state: PlayerState, serial: number, reason: string)
	if not current(player, state, serial) then
		return
	end
	disconnect(state)
	reportFailure(player, state, reason)
	scheduleRetry(player, state)
end

local function applySnapshot(player: Player, state: PlayerState, snapshot: any, serial: number)
	if not current(player, state, serial) or state.snapshot ~= snapshot then
		return
	end
	local okError, errorState = pcall(function()
		return snapshot.Error
	end)
	if not okError or errorState ~= Enum.ConfigSnapshotErrorState.None then
		fail(
			player,
			state,
			serial,
			`ConfigService:GetConfigForPlayerAsync(player.UserId={player.UserId}).Error = {tostring(errorState)}; expected None`
		)
		return
	end
	local ok, reason, bySchema = readCandidate(player, state, snapshot, serial)
	if not current(player, state, serial) then
		return
	end
	if not ok or bySchema == nil then
		fail(player, state, serial, reason or "ConfigService candidate read failed")
		return
	end
	local projected, projectReason = projectCandidate(player, bySchema)
	if not projected then
		fail(player, state, serial, projectReason or "projection failed")
		return
	end
	reportRecovery(player, state)
end

acquire = function(player: Player, state: PlayerState)
	if states[player] ~= state or player.Parent ~= Players then
		return
	end
	state.serial += 1
	local serial = state.serial
	disconnect(state)
	if not state.defaultsProjected then
		local ok, reason, bySchema = defaults()
		if not ok or bySchema == nil then
			fail(player, state, serial, reason or "invalid default schema")
			return
		end
		local projected, projectReason = projectCandidate(player, bySchema)
		if not projected then
			fail(player, state, serial, projectReason or "default projection failed")
			return
		end
		state.defaultsProjected = true
	end

	local ok, snapshot = pcall(ConfigService.GetConfigForPlayerAsync, ConfigService, player)
	if not current(player, state, serial) then
		return
	end
	if not ok or snapshot == nil then
		fail(
			player,
			state,
			serial,
			`ConfigService:GetConfigForPlayerAsync(player.UserId={player.UserId}) failed: {tostring(snapshot)}`
		)
		return
	end
	state.snapshot = snapshot
	local observer = state.observer
	local connected, connection = pcall(function()
		return snapshot.UpdateAvailable:Connect(function()
			if
				states[player] ~= state
				or player.Parent ~= Players
				or state.snapshot ~= snapshot
				or state.observer ~= observer
			then
				return
			end
			state.serial += 1
			local updateSerial = state.serial
			local refreshed, refreshError = pcall(snapshot.Refresh, snapshot)
			if not current(player, state, updateSerial) or state.snapshot ~= snapshot or state.observer ~= observer then
				return
			end
			if not refreshed then
				fail(
					player,
					state,
					updateSerial,
					`ConfigService:GetConfigForPlayerAsync(player.UserId={player.UserId}).Refresh failed: {refreshError}`
				)
				return
			end
			applySnapshot(player, state, snapshot, updateSerial)
		end)
	end)
	if
		states[player] ~= state
		or player.Parent ~= Players
		or state.snapshot ~= snapshot
		or state.observer ~= observer
	then
		if connected and connection then
			connection:Disconnect()
		end
		return
	end
	if not connected or connection == nil then
		fail(
			player,
			state,
			serial,
			`ConfigService:GetConfigForPlayerAsync(player.UserId={player.UserId}).UpdateAvailable:Connect failed: {tostring(
				connection
			)}`
		)
		return
	end
	state.connection = connection
	applySnapshot(player, state, snapshot, serial)
end

function PlayerConfigService.start(context: { schemas: { Schema }, retrySeconds: number? })
	if started then
		return
	end
	started = true
	schemas = context.schemas
	retrySeconds = context.retrySeconds or 30

	local function added(player: Player)
		if states[player] ~= nil then
			return
		end
		local state: PlayerState = {
			snapshot = nil,
			connection = nil,
			retryPending = false,
			defaultsProjected = false,
			serial = 0,
			observer = 0,
			lastFailure = nil,
		}
		states[player] = state
		task.spawn(acquire, player, state)
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state ~= nil then
			state.serial += 1
			disconnect(state)
			states[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		added(player)
	end
end

return PlayerConfigService
