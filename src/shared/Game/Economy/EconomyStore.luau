--!strict

-- Client projection of the replicated GameProfile economy data.

export type EconomyData = {
	Bonks: number,
	Cosmetics: {
		Owned: { [string]: boolean },
		Equipped: { [string]: string? },
	},
	Entitlements: {
		PremiumSeasons: { [string]: boolean },
	}?,
}

type ChangedCallback = (data: EconomyData) -> ()

local EconomyStore = {}

local started = false
local replicaSource: any = nil
local profileReplica: any = nil
local newReplicaConnection: any = nil
local profileChangeConnection: any = nil
local callbacks: { ChangedCallback } = {}

local function disconnect(connection: any?)
	if connection and type(connection.Disconnect) == "function" then
		connection:Disconnect()
	end
end

local function snapshot(): EconomyData?
	local replica = profileReplica
	if replica == nil or type(replica.Data) ~= "table" then
		return nil
	end
	return replica.Data :: EconomyData
end

local function notify()
	local data = snapshot()
	if data == nil then
		return
	end
	for _, callback in callbacks do
		local ok, err = pcall(callback, data)
		if not ok then
			warn(`[EconomyStore] changed callback failed: {err}`)
		end
	end
end

local function watchProfile(replica: any)
	disconnect(profileChangeConnection)
	profileReplica = replica
	profileChangeConnection = replica:OnChange(function(_action: string, path: { any })
		local root = path[1]
		if root == "Bonks" or root == "Cosmetics" or root == "Entitlements" then
			notify()
		end
	end)
	notify()
end

function EconomyStore.start(sourceOverride: any?)
	if started then
		return
	end
	started = true
	if sourceOverride then
		replicaSource = sourceOverride
	else
		local replicatedStorage = game:GetService("ReplicatedStorage")
		replicaSource = require(replicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
	end
	newReplicaConnection = replicaSource.OnNew("GameProfile", watchProfile)
end

function EconomyStore.snapshot(): EconomyData?
	return snapshot()
end

function EconomyStore.onChanged(callback: ChangedCallback): () -> ()
	table.insert(callbacks, callback)
	local connected = true
	local data = snapshot()
	if data then
		callback(data)
	end
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

function EconomyStore.stop()
	disconnect(profileChangeConnection)
	disconnect(newReplicaConnection)
	started = false
	replicaSource = nil
	profileReplica = nil
	newReplicaConnection = nil
	profileChangeConnection = nil
	table.clear(callbacks)
end

function EconomyStore._resetForTest()
	EconomyStore.stop()
end

return EconomyStore
