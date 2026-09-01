-- Name: SettingsStore.luau
-- Author: Jack C.
-- Description: Client-side current value for every setting: the authoritative source every control and every consuming system reads. A local write applies and notifies instantly; persistence is a separate, explicit commit so dragging a slider never waits on or spams the network.
-- Created: 2026-08-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsRegistry = require(script.Parent.SettingsRegistry)
local SettingsValues = require(script.Parent.SettingsValues)

type ChangedCallback = (id: string) -> ()

local SettingsStore = {}

local started = false
local replicaSource: any = nil
local profileReplica: any = nil
local newReplicaConnection: any = nil
local profileChangeConnection: any = nil
local network: any = nil
local localValues: { [string]: any } = {}
local callbacks: { ChangedCallback } = {}

local function disconnect(connection: any?)
	if connection and type(connection.Disconnect) == "function" then
		connection:Disconnect()
	end
end

local function notify(id: string)
	for _, callback in table.clone(callbacks) do
		local ok, err = pcall(callback, id)
		if not ok then
			warn(`[SettingsStore] changed callback failed: {err}`)
		end
	end
end

local function replicatedValue(id: string): any
	local replica = profileReplica
	if replica == nil or type(replica.Data) ~= "table" then
		return nil
	end
	local settings = replica.Data.Settings
	if type(settings) ~= "table" then
		return nil
	end
	return settings[id]
end

function SettingsStore.get(id: string): any
	local definition = SettingsRegistry.get(id)
	if definition == nil then
		return nil
	end
	if localValues[id] ~= nil then
		return localValues[id]
	end
	local replicated = replicatedValue(id)
	if replicated ~= nil then
		return SettingsValues.normalize(definition, replicated)
	end
	return definition.Default
end

function SettingsStore.set(id: string, value: any)
	local definition = SettingsRegistry.get(id)
	if definition == nil then
		return
	end
	local normalized = SettingsValues.normalize(definition, value)
	if localValues[id] == normalized then
		return
	end
	localValues[id] = normalized
	notify(id)
end

function SettingsStore.commit(id: string)
	local definition = SettingsRegistry.get(id)
	if definition == nil or not SettingsRegistry.isPersisted(definition) then
		return
	end
	if network == nil then
		return
	end
	network.fireServer("SetClientSetting", id, SettingsStore.get(id))
end

function SettingsStore.reset(id: string)
	local definition = SettingsRegistry.get(id)
	if definition == nil then
		return
	end
	SettingsStore.set(id, definition.Default)
	SettingsStore.commit(id)
end

local function watchProfile(replica: any)
	disconnect(profileChangeConnection)
	profileReplica = replica
	profileChangeConnection = replica:OnChange(function(_action: string, path: { any })
		if path[1] ~= "Settings" then
			return
		end
		local id = path[2]
		if type(id) == "string" then
			notify(id)
		else
			for _, definition in SettingsRegistry.all() do
				notify(definition.Id)
			end
		end
	end)
end

function SettingsStore.start(overrides: { replica: any?, network: any? }?)
	if started then
		return
	end
	started = true
	if overrides and overrides.replica then
		replicaSource = overrides.replica
	else
		replicaSource = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
	end
	network = if overrides and overrides.network
		then overrides.network
		else require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
	newReplicaConnection = replicaSource.OnNew("GameProfile", watchProfile)
end

function SettingsStore.subscribe(callback: ChangedCallback): () -> ()
	table.insert(callbacks, callback)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

function SettingsStore.stop()
	disconnect(profileChangeConnection)
	disconnect(newReplicaConnection)
	started = false
	replicaSource = nil
	network = nil
	profileReplica = nil
	newReplicaConnection = nil
	profileChangeConnection = nil
	table.clear(localValues)
	table.clear(callbacks)
end

function SettingsStore._resetForTest()
	SettingsStore.stop()
end

return SettingsStore
