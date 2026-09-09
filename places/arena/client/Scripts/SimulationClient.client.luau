-- Description: Arena client entry point for gameplay: starts every input, presentation, and audio module and wires them to the replicated match and combat state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

while ReplicatedFirst:GetAttribute("ReactLoadingPresented") ~= true do
	ReplicatedFirst:GetAttributeChangedSignal("ReactLoadingPresented"):Wait()
end
local StarterPlayer = game:GetService("StarterPlayer")

local ConfigRoot = ReplicatedStorage:WaitForChild("Config")
local Debug = require(ConfigRoot:WaitForChild("Infra"):WaitForChild("Debug"))
local LiveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LiveConfig"))
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
local combatPresenters = {}
local damagePresenters = {}
local DeathEffects
local FanAirflow

ConfigReplication.startClient(LiveConfig.loadModules("arena"))
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

local systems = {
	{ name = "ArmIK", parent = Presentation, method = "start" },
	{ name = "BallVisuals", parent = Presentation, method = "start", combat = true },
	{ name = "DamageFeedback", parent = Presentation, method = "start", damage = "onEvent" },
	{
		name = "DeathEffects",
		parent = Presentation,
		method = "start",
		damage = "notifyElim",
		onLoaded = function(module)
			DeathEffects = module
		end,
	},
	{ name = "HammerVisuals", parent = Presentation, method = "start", combat = true },
	{ name = "SplatEffects", parent = Presentation, method = "start", combat = true },
	{
		name = "CosmeticEffects",
		load = function()
			return require(
				ReplicatedStorage:WaitForChild("Shared")
					:WaitForChild("Game")
					:WaitForChild("Cosmetics")
					:WaitForChild("CosmeticEffects")
			)
		end,
		method = "start",
		combat = true,
	},
	{ name = "MatchAudio", parent = Presentation, method = "start" },
	{ name = "GameAudio", parent = Presentation, combat = true },
	{ name = "PlayerHighlights", parent = Presentation, method = "start" },
	{ name = "JumpPadVisuals", parent = Presentation, method = "start" },
	{
		name = "FanAirflow",
		parent = Presentation,
		method = "start",
		onLoaded = function(module)
			FanAirflow = module
		end,
	},
	{ name = "RotatingPlatforms", parent = MapFeatures, method = "load" },
	{ name = "PlatformRider", parent = Movement, method = "start" },
	{ name = "DebugVisuals", parent = DebugModules, method = "start", combat = true },
	{ name = "ThrowPoseTuner", parent = DebugModules, method = "start" },
	{ name = "CosmeticVFXGallery", parent = DebugModules, method = "start" },
	{ name = "DevMatchSkip", parent = DebugModules, method = "start" },
	{ name = "ChargeAim", parent = Presentation, method = "start" },
	{ name = "WeaponAnimations", parent = Presentation, method = "start", intent = true },
}
for _, system in systems do
	local ok, err = pcall(function()
		local module = if system.load then system.load() else require(system.parent:WaitForChild(system.name))
		if system.onLoaded then
			system.onLoaded(module)
		end
		if system.method then
			module[system.method]()
		end
		if system.combat then
			table.insert(combatPresenters, module.onEvent)
		end
		if system.damage then
			table.insert(damagePresenters, module[system.damage])
		end
		if system.intent then
			table.insert(connections, CombatInputSender.onIntent(module.onIntent))
		end
	end)
	if not ok then
		warn(`[SimulationClient] Optional {system.name} unavailable: {err}`)
	end
end

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

local function presentCombatEvent(event)
	for _, present in combatPresenters do
		present(event)
	end
	if Debug.CombatTrace and (event.kind == "Elim" or event.kind == "BallThrown") then
		print(`[Combat/client] {event.kind} {event.projectileId or ""}`)
	end
end

table.insert(
	connections,
	Network.on("CombatSimEvent", function(events)
		for _, event in events do
			presentCombatEvent(event)
		end
	end)
)

table.insert(
	connections,
	Network.on("CombatFeed", function(event)
		if event.kind == "Elim" then
			presentCombatEvent(event)
		end
	end)
)

table.insert(
	connections,
	Network.on("DamageFeedback", function(event)
		for _, present in damagePresenters do
			present(event)
		end
	end)
)

script.Destroying:Connect(function()
	Combat.setInputEnabled(false)
	if FanAirflow then
		FanAirflow.stop()
	end
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
	if DeathEffects then
		DeathEffects.destroy()
	end
end)
