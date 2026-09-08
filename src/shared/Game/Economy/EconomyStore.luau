-- Description: Client-side projection of the replicated profile economy data, exposing a snapshot and change subscription the storefront and inventory UI read from.

--!strict

local Listeners = require(script.Parent.Parent.Util.Listeners)

export type EconomyData = {
	Bonks: number,
	Cosmetics: {
		Owned: { [string]: boolean },
		Equipped: { [string]: string? },
	},
	Crates: { Pity: { [string]: { [string]: number } } }?,
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
local callbacks: Listeners.Collection<EconomyData> = Listeners.new("EconomyStore", false, "changed callback failed")

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
	callbacks.emit(data)
end

local function watchProfile(replica: any)
	disconnect(profileChangeConnection)
	profileReplica = replica
	profileChangeConnection = replica:OnChange(function(_action: string, path: { any })
		local root = path[1]
		if root == "Bonks" or root == "Cosmetics" or root == "Entitlements" or root == "Crates" then
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

function EconomyStore.subscribe(callback: ChangedCallback): () -> ()
	local unsubscribe = callbacks.add(callback)
	local data = snapshot()
	if data then
		callback(data)
	end
	return unsubscribe
end

function EconomyStore.stop()
	disconnect(profileChangeConnection)
	disconnect(newReplicaConnection)
	started = false
	replicaSource = nil
	profileReplica = nil
	newReplicaConnection = nil
	profileChangeConnection = nil
	callbacks.clear()
end

function EconomyStore._resetForTest()
	EconomyStore.stop()
end

return EconomyStore
