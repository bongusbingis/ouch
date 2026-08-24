--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local ArenaTeleportClient = {}

export type Snapshot = {
	direction: string,
	state: string,
	attempt: number,
	maxAttempts: number,
	retryAt: number?,
	reason: string?,
}?

local started = false
local snapshot: Snapshot = nil
local listeners: { (Snapshot) -> () } = {}
local connection: RBXScriptConnection? = nil

local function publish(value: Snapshot)
	snapshot = value
	for _, listener in listeners do
		local ok, err = pcall(listener, value)
		if not ok then
			warn(`[ArenaTeleportClient] listener failed: {err}`)
		end
	end
end

function ArenaTeleportClient.start()
	if started then
		return
	end
	started = true
	connection = Network.on("TeleportStatus", function(packet)
		if typeof(packet) ~= "table" or packet.direction ~= "Lobby" or typeof(packet.state) ~= "string" then
			return
		end
		publish({
			direction = packet.direction,
			state = packet.state,
			attempt = if typeof(packet.attempt) == "number" then packet.attempt else 0,
			maxAttempts = if typeof(packet.maxAttempts) == "number" then packet.maxAttempts else 0,
			retryAt = if typeof(packet.retryAt) == "number" then packet.retryAt else nil,
			reason = if typeof(packet.reason) == "string" then packet.reason else nil,
		})
	end)
end

function ArenaTeleportClient.getSnapshot(): Snapshot
	return snapshot
end

function ArenaTeleportClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	ArenaTeleportClient.start()
	table.insert(listeners, listener)
	listener(snapshot)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function ArenaTeleportClient.retry()
	Network.fireServer("RequestLobbyReturn", "Retry")
end

function ArenaTeleportClient.stay()
	Network.fireServer("RequestLobbyReturn", "Stay")
end

function ArenaTeleportClient.returnToLobby()
	Network.fireServer("RequestLobbyReturn", "Return")
end

function ArenaTeleportClient.destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	table.clear(listeners)
	snapshot = nil
	started = false
end

return ArenaTeleportClient
