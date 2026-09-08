-- Description: Client-side current value for every setting: the authoritative source every control and every consuming system reads. A local write applies and notifies instantly; persistence is a separate, explicit commit so dragging a slider never waits on or spams the network.

--!strict

local Listeners = require(script.Parent.Parent.Util.Listeners)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsRegistry = require(script.Parent.SettingsRegistry)
local SettingsValues = require(script.Parent.SettingsValues)
local ClientRequest = require(script.Parent.Parent.Data.ClientRequest)

type ChangedCallback = (id: string) -> ()

local SettingsStore = {}

local started = false
local replicaSource: any = nil
local profileReplica: any = nil
local newReplicaConnection: any = nil
local profileChangeConnection: any = nil
local network: any = nil
local localValues: { [string]: any } = {}
local revisions: { [string]: number } = {}
local queued: { [string]: any } = {}
local workers: { [string]: boolean } = {}
local statuses: { [string]: string } = {}
local generation = 0
local callbacks: Listeners.Collection<string> = Listeners.new("SettingsStore", true, "changed callback failed")

local function disconnect(connection: any?)
	if connection and type(connection.Disconnect) == "function" then
		connection:Disconnect()
	end
end

local function notify(id: string)
	callbacks.emit(id)
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
	revisions[id] = (revisions[id] or 0) + 1
	statuses[id] = nil
	notify(id)
end

function SettingsStore.status(id: string): string?
	return statuses[id]
end

function SettingsStore.commit(id: string)
	local definition = SettingsRegistry.get(id)
	if definition == nil or not SettingsRegistry.isPersisted(definition) or network == nil then
		return
	end
	queued[id] = { value = SettingsStore.get(id), revision = revisions[id] or 0 }
	statuses[id] = "pending"
	notify(id)
	if workers[id] then
		return
	end
	workers[id] = true
	local currentGeneration = generation
	local activeNetwork = network
	task.spawn(function()
		while queued[id] and currentGeneration == generation do
			local request = queued[id]
			queued[id] = nil
			local callOk, accepted, _reason, value =
				ClientRequest(activeNetwork.call, "SetClientSettingRequest", id, request.value)
			if currentGeneration ~= generation then
				return
			end
			if request.revision == (revisions[id] or 0) then
				if callOk and accepted == true and value ~= nil then
					local normalized = SettingsValues.normalize(definition, value)
					localValues[id] = if replicatedValue(id) == normalized then nil else normalized
					statuses[id] = nil
				else
					localValues[id] = nil
					statuses[id] = "failed"
				end
				notify(id)
			end
		end
		workers[id] = nil
	end)
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
			if localValues[id] == replicatedValue(id) then
				localValues[id] = nil
			end
			notify(id)
		else
			for _, definition in SettingsRegistry.all() do
				notify(definition.Id)
			end
		end
	end)
	for _, definition in SettingsRegistry.all() do
		notify(definition.Id)
	end
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
	local unsubscribe = callbacks.add(callback)
	return unsubscribe
end

function SettingsStore.stop()
	generation += 1
	table.clear(revisions)
	table.clear(queued)
	table.clear(workers)
	table.clear(statuses)
	disconnect(profileChangeConnection)
	disconnect(newReplicaConnection)
	started = false
	replicaSource = nil
	network = nil
	profileReplica = nil
	newReplicaConnection = nil
	profileChangeConnection = nil
	table.clear(localValues)
	callbacks.clear()
end

function SettingsStore._resetForTest()
	SettingsStore.stop()
end

return SettingsStore
