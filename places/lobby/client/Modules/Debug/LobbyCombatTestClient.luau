-- Description: Studio-only client controller for the lobby combat/cosmetics test session. Presses Q to toggle the session, hands the combat camera and input over while it runs, and drives the shared CosmeticEffects driver from broadcast sim events so equipped cosmetics render exactly as they do in the arena. Presentation only; the server owns the session and judges hits.

--!strict

local Listeners = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Util")
		:WaitForChild("Listeners")
)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Debug = require(Config:WaitForChild("Infra"):WaitForChild("Debug"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CosmeticEffects = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticEffects")
)
local GameAudio = require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("GameAudio"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

export type Snapshot = { active: boolean }

local LobbyCombatTestClient = {}

local started = false
local connections: { RBXScriptConnection } = {}
local listeners: Listeners.Collection<Snapshot> = Listeners.new("LobbyCombatTestClient", true, "listener failed")
local state: Snapshot = { active = false }

local function enabled(): boolean
	return Debug.LobbyCombatTest == true and RunService:IsStudio()
end

local function publish(active: boolean)
	if state.active == active then
		return
	end
	state = { active = active }
	listeners.emitWith(function(callback)
		callback(state)
	end)
end

function LobbyCombatTestClient.getSnapshot(): Snapshot
	return state
end

function LobbyCombatTestClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	local unsubscribe = listeners.add(listener)
	listener(state)
	return unsubscribe
end

local function onState(packet: any)
	if typeof(packet) ~= "table" then
		return
	end
	if packet.active == true then
		Combat.setCameraEnabled(true)
		Combat.setInputEnabled(true)
		Combat.setWeaponLocked(false)
		publish(true)
	else
		Combat.setInputEnabled(false)
		Combat.setCameraEnabled(false)
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
		publish(false)
	end
end

function LobbyCombatTestClient.start()
	if started then
		return
	end
	if not enabled() then
		return
	end
	started = true

	CosmeticEffects.start()

	table.insert(connections, Network.on("LobbyCombatTest", onState))
	table.insert(
		connections,
		Network.on("CombatSimEvent", function(events)
			for _, event in events do
				CosmeticEffects.onEvent(event)
				GameAudio.onEvent(event)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or input.KeyCode ~= Enum.KeyCode.Q then
				return
			end
			if UserInputService:GetFocusedTextBox() ~= nil then
				return
			end
			Network.fireServer("LobbyCombatTest", "Toggle")
		end)
	)
end

function LobbyCombatTestClient.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	listeners.clear()
	Combat.setInputEnabled(false)
	Combat.setCameraEnabled(false)
	state = { active = false }
	started = false
end

return LobbyCombatTestClient
