-- Description: Client adapter for the authoritative Splashdown race: decodes the replicated race snapshot, folds in the local racer's attributes and the roster's names into one HUD view, and relays race events, so the HUD, camera, audio and effects all read a single projection.

--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local Presentation = require(Config:WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local Listeners = require(Game:WaitForChild("Util"):WaitForChild("Listeners"))
local PlayerIds = require(Game:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local SplashdownState = require(Game:WaitForChild("Splashdown"):WaitForChild("SplashdownState"))
local SplashdownHUDModel = require(Shared:WaitForChild("UI"):WaitForChild("Models"):WaitForChild("SplashdownHUDModel"))
local Network = require(Shared:WaitForChild("Network"))
local RisingLiquidClient = require(script.Parent:WaitForChild("RisingLiquidClient"))

local SplashdownClient = {}

export type Snapshot = SplashdownState.Snapshot
export type View = SplashdownHUDModel.View
export type Event = { [string]: any }

local player = Players.LocalPlayer
local Attributes = Splashdown.Attributes

local started = false
local snapshot: Snapshot = SplashdownState.idle()
local view: View = SplashdownHUDModel.build({ snapshot = snapshot, localPlayerId = PlayerIds.toId(player) }, 0)
local snapshotListeners: Listeners.Collection<Snapshot> = Listeners.new("SplashdownClient", true, "listener failed")
local viewListeners: Listeners.Collection<View> = Listeners.new("SplashdownClient", true, "view listener failed")
local eventListeners: Listeners.Collection<Event> = Listeners.new("SplashdownClient", true, "event listener failed")
local connections: { RBXScriptConnection } = {}
local stateConnections: { RBXScriptConnection } = {}
local heartbeat: RBXScriptConnection? = nil
local elapsed = 0

local function names(): { [string]: string }
	local result = {}
	for _, member in Players:GetPlayers() do
		result[PlayerIds.toId(member)] = member.DisplayName
	end
	return result
end

local function rebuildView()
	local finishTime = player:GetAttribute(Attributes.FinishTime)
	local nextView = SplashdownHUDModel.build({
		snapshot = snapshot,
		localPlayerId = PlayerIds.toId(player),
		checkpoint = player:GetAttribute(Attributes.Checkpoint) :: number?,
		finishTime = if typeof(finishTime) == "number" then finishTime else nil,
		splashes = player:GetAttribute(Attributes.Splashes) :: number?,
		roundPoints = player:GetAttribute(Attributes.RoundPoints) :: number?,
		names = names(),
	}, Workspace:GetServerTimeNow())
	view = nextView
	viewListeners.emit(view)
end

local function updateHeartbeat()
	local active = snapshot.phase == SplashdownState.Phases.Racing or snapshot.phase == SplashdownState.Phases.Countdown
	if active and heartbeat == nil then
		elapsed = 0
		heartbeat = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= Presentation.HUD.UpdateSeconds then
				elapsed = 0
				rebuildView()
			end
		end)
	elseif not active and heartbeat ~= nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function decode(value: string)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, value)
	if not ok then
		return
	end
	local decoded = SplashdownState.sanitize(data)
	if decoded == nil then
		return
	end
	snapshot = decoded
	snapshotListeners.emit(snapshot)
	updateHeartbeat()
	rebuildView()
end

local function attach(folder: Folder)
	local function attachValue(child: Instance)
		if child.Name ~= Splashdown.SnapshotValueName or not child:IsA("StringValue") then
			return
		end
		table.insert(
			stateConnections,
			child:GetPropertyChangedSignal("Value"):Connect(function()
				decode(child.Value)
			end)
		)
		decode(child.Value)
	end
	local existing = folder:FindFirstChild(Splashdown.SnapshotValueName)
	if existing then
		attachValue(existing)
	end
	table.insert(stateConnections, folder.ChildAdded:Connect(attachValue))
end

function SplashdownClient.start()
	if started then
		return
	end
	started = true
	RisingLiquidClient.start()
	local existing = ReplicatedStorage:FindFirstChild(Splashdown.StateFolderName)
	if existing and existing:IsA("Folder") then
		attach(existing)
	end
	table.insert(
		connections,
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == Splashdown.StateFolderName and child:IsA("Folder") then
				attach(child)
			end
		end)
	)
	for _, name in { Attributes.Checkpoint, Attributes.FinishTime, Attributes.Splashes, Attributes.RoundPoints } do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(rebuildView))
	end
	table.insert(
		connections,
		Network.on("SplashdownEvent", function(payload)
			if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" then
				return
			end
			eventListeners.emit(payload)
		end)
	)
	updateHeartbeat()
end

function SplashdownClient.getSnapshot(): Snapshot
	return snapshot
end

function SplashdownClient.subscribe(callback: (Snapshot) -> ()): () -> ()
	SplashdownClient.start()
	local unsubscribe = snapshotListeners.add(callback)
	callback(snapshot)
	return unsubscribe
end

function SplashdownClient.getView(): View
	return view
end

function SplashdownClient.subscribeView(callback: (View) -> ()): () -> ()
	SplashdownClient.start()
	local unsubscribe = viewListeners.add(callback)
	callback(view)
	return unsubscribe
end

function SplashdownClient.onEvent(callback: (Event) -> ()): () -> ()
	SplashdownClient.start()
	return eventListeners.add(callback)
end

function SplashdownClient.isLocalRacer(): boolean
	return snapshot.phase ~= SplashdownState.Phases.Idle
end

function SplashdownClient.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, connection in stateConnections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(stateConnections)
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	snapshotListeners.clear()
	viewListeners.clear()
	eventListeners.clear()
	RisingLiquidClient.destroy()
	started = false
end

return SplashdownClient
