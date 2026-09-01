-- Name: SimulationClient.client.luau
-- Author: Jack C.
-- Description: Arena client entry point for gameplay: starts every input, presentation, and audio module and wires them to the replicated match and combat state.
-- Created: 2026-07-12

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

while ReplicatedFirst:GetAttribute("ReactLoadingPresented") ~= true do
	ReplicatedFirst:GetAttributeChangedSignal("ReactLoadingPresented"):Wait()
end
local StarterPlayer = game:GetService("StarterPlayer")

local ConfigRoot = ReplicatedStorage:WaitForChild("Config")
local Debug = require(ConfigRoot:WaitForChild("Debug"))
local ConfigReplication = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("ConfigReplication")
)

local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local InputModules = Client:WaitForChild("Modules"):WaitForChild("Input")
local InputRouter = require(InputModules:WaitForChild("InputRouter"))
local CombatInputSender = require(InputModules:WaitForChild("CombatInputSender"))
local AssistConfig = require(InputModules:WaitForChild("AssistConfig"))
local CameraAssist = require(InputModules:WaitForChild("CameraAssist"))
local Presentation = Client:WaitForChild("Modules"):WaitForChild("Presentation")
local CombatState = require(Presentation:WaitForChild("CombatState"))
local VoteCamera = require(Presentation:WaitForChild("VoteCamera"))
local DebugModules = Client:WaitForChild("Modules"):WaitForChild("Debug")
local Movement = Client:WaitForChild("Modules"):WaitForChild("Movement")
local MapFeatures = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures")
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local ArenaLoadingClient = require(Client:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ArenaLoadingClient"))

local connections = {}
local optionalSystems = {}
local BallVisuals
local DamageFeedback
local DeathEffects
local HammerVisuals
local SplatEffects
local CosmeticEffects
local GameAudio
local DebugVisuals

local function startOptional(name, callback)
	local ok, err = pcall(callback)
	optionalSystems[name] = ok
	if not ok then
		warn(`[SimulationClient] Optional {name} unavailable: {err}`)
	end
	return ok
end

ConfigReplication.startClient({
	Combat = require(ConfigRoot:WaitForChild("Combat")),
	AimAssist = require(ConfigRoot:WaitForChild("AimAssist")),
	GameModes = require(ConfigRoot:WaitForChild("GameModes")),
	MapFeatures = require(ConfigRoot:WaitForChild("MapFeatures")),
	Shop = require(ConfigRoot:WaitForChild("Shop")),
	Crates = require(ConfigRoot:WaitForChild("Crates")),
})
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
Combat.setCameraEnabled(true)
Combat.setInputEnabled(false)

AssistConfig.start()
CombatState.start()
InputRouter.start()
CameraAssist.start()
CombatInputSender.start()
VoteCamera.start()
ArenaLoadingClient.markSimulationReady()

startOptional("ArmIK", function()
	require(Presentation:WaitForChild("ArmIK")).start()
end)
startOptional("BallVisuals", function()
	BallVisuals = require(Presentation:WaitForChild("BallVisuals"))
	BallVisuals.start()
end)
startOptional("DamageFeedback", function()
	DamageFeedback = require(Presentation:WaitForChild("DamageFeedback"))
	DamageFeedback.start()
end)
startOptional("DeathEffects", function()
	DeathEffects = require(Presentation:WaitForChild("DeathEffects"))
	DeathEffects.start()
end)
startOptional("HammerVisuals", function()
	HammerVisuals = require(Presentation:WaitForChild("HammerVisuals"))
	HammerVisuals.start()
end)
startOptional("SplatEffects", function()
	SplatEffects = require(Presentation:WaitForChild("SplatEffects"))
	SplatEffects.start()
end)
startOptional("CosmeticEffects", function()
	CosmeticEffects = require(
		ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Game")
			:WaitForChild("Cosmetics")
			:WaitForChild("CosmeticEffects")
	)
	CosmeticEffects.start()
end)
startOptional("MatchAudio", function()
	require(Presentation:WaitForChild("MatchAudio")).start()
end)
startOptional("GameAudio", function()
	GameAudio = require(Presentation:WaitForChild("GameAudio"))
end)
startOptional("PlayerHighlights", function()
	require(Presentation:WaitForChild("PlayerHighlights")).start()
end)
startOptional("JumpPadVisuals", function()
	require(Presentation:WaitForChild("JumpPadVisuals")).start()
end)
startOptional("RotatingPlatforms", function()
	require(MapFeatures:WaitForChild("RotatingPlatforms")).load()
end)
startOptional("PlatformRider", function()
	require(Movement:WaitForChild("PlatformRider")).start()
end)
startOptional("DebugVisuals", function()
	DebugVisuals = require(DebugModules:WaitForChild("DebugVisuals"))
	DebugVisuals.start()
end)
startOptional("ThrowPoseTuner", function()
	require(DebugModules:WaitForChild("ThrowPoseTuner")).start()
end)
startOptional("CosmeticVFXGallery", function()
	require(DebugModules:WaitForChild("CosmeticVFXGallery")).start()
end)
startOptional("DevMatchSkip", function()
	require(DebugModules:WaitForChild("DevMatchSkip")).start()
end)
startOptional("ChargeAim", function()
	require(Presentation:WaitForChild("ChargeAim")).start()
end)
startOptional("WeaponAnimations", function()
	local WeaponAnimations = require(Presentation:WaitForChild("WeaponAnimations"))
	WeaponAnimations.start()
	table.insert(connections, CombatInputSender.onIntent(WeaponAnimations.onIntent))
end)

local matchState: Folder? = nil
local matchStateConnection: RBXScriptConnection? = nil
local function updateCombatInput()
	Combat.setInputEnabled(
		Players.LocalPlayer:GetAttribute("ArenaReady") == true
			and matchState ~= nil
			and matchState:GetAttribute("phase") == "Active"
	)
end

local function attachMatchState(folder: Folder)
	if matchStateConnection then
		matchStateConnection:Disconnect()
	end
	matchState = folder
	matchStateConnection = folder:GetAttributeChangedSignal("phase"):Connect(updateCombatInput)
	updateCombatInput()
end

local existingMatchState = ReplicatedStorage:FindFirstChild("MatchState")
if existingMatchState and existingMatchState:IsA("Folder") then
	attachMatchState(existingMatchState)
end
table.insert(
	connections,
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "MatchState" and child:IsA("Folder") then
			attachMatchState(child)
		end
	end)
)
table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal("ArenaReady"):Connect(updateCombatInput))

table.insert(
	connections,
	Network.on("CombatSimEvent", function(events)
		for _, event in events do
			if optionalSystems.BallVisuals then
				BallVisuals.onEvent(event)
			end
			if optionalSystems.HammerVisuals then
				HammerVisuals.onEvent(event)
			end
			if optionalSystems.SplatEffects then
				SplatEffects.onEvent(event)
			end
			if optionalSystems.CosmeticEffects then
				CosmeticEffects.onEvent(event)
			end
			if optionalSystems.GameAudio then
				GameAudio.onEvent(event)
			end
			if optionalSystems.DebugVisuals then
				DebugVisuals.onEvent(event)
			end
			if Debug.CombatTrace and (event.kind == "Elim" or event.kind == "BallThrown") then
				print(`[Combat/client] {event.kind} {event.projectileId or ""}`)
			end
		end
	end)
)

table.insert(
	connections,
	Network.on("DamageFeedback", function(event)
		if optionalSystems.DamageFeedback then
			DamageFeedback.onEvent(event)
		end
		if optionalSystems.DeathEffects then
			DeathEffects.notifyElim(event)
		end
	end)
)

script.Destroying:Connect(function()
	Combat.setInputEnabled(false)
	if matchStateConnection then
		matchStateConnection:Disconnect()
	end
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		else
			connection()
		end
	end
	InputRouter.destroy()
	CombatInputSender.destroy()
	CombatState.destroy()
	VoteCamera.destroy()
end)
