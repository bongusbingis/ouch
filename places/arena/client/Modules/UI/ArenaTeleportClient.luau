-- Description: Client adapter for the return-to-lobby teleport, publishing the teleport status the UI shows and exposing retry, stay, and manual return actions.

--!strict

local Listeners = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Util")
		:WaitForChild("Listeners")
)

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
	canRetry: boolean?,
	canStay: boolean?,
	waitingForParty: boolean?,
	recoveryAvailable: boolean?,
}?

local started = false
local snapshot: Snapshot = nil
local listeners: Listeners.Collection<Snapshot> = Listeners.new("ArenaTeleportClient", false, "listener failed")
local connection: RBXScriptConnection? = nil

local function publish(value: Snapshot)
	snapshot = value
	listeners.emit(value)
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
			canRetry = if typeof(packet.canRetry) == "boolean" then packet.canRetry else nil,
			canStay = if typeof(packet.canStay) == "boolean" then packet.canStay else nil,
			waitingForParty = packet.waitingForParty == true,
			recoveryAvailable = packet.recoveryAvailable == true,
		})
	end)
end

function ArenaTeleportClient.getSnapshot(): Snapshot
	return snapshot
end

function ArenaTeleportClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	ArenaTeleportClient.start()
	local unsubscribe = listeners.add(listener)
	listener(snapshot)
	return unsubscribe
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
	listeners.clear()
	snapshot = nil
	started = false
end

return ArenaTeleportClient
