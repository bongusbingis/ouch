-- Description: Arena client entry point for gameplay: starts every input, presentation, and audio module and wires them to the replicated match and combat state.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

while ReplicatedFirst:GetAttribute("ReactLoadingPresented") ~= true do
	ReplicatedFirst:GetAttributeChangedSignal("ReactLoadingPresented"):Wait()
end
local StarterPlayer = game:GetService("StarterPlayer")

local ConfigRoot = ReplicatedStorage:WaitForChild("Config")
local Debug = require(ConfigRoot:WaitForChild("Infra"):WaitForChild("Debug"))
local GameModes = require(ConfigRoot:WaitForChild("Gameplay"):WaitForChild("GameModes"))
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

local connections: { any } = {}
local loadedModules: { any } = {}
local startedCore: { () -> () } = {}
local combatPresenters: { any } = {}
local damagePresenters: { any } = {}
local DeathEffects: any = nil
local FanAirflow: any = nil
local matchState: Folder? = nil
local matchStateConnection: RBXScriptConnection? = nil
local matchStateModeConnection: RBXScriptConnection? = nil
local cleaned = false

local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
Combat.setInputEnabled(false)

local function cleanup()
	if cleaned then
		return
	end
	cleaned = true
	Combat.setInputEnabled(false)
	if matchStateConnection then
		matchStateConnection:Disconnect()
		matchStateConnection = nil
	end
	if matchStateModeConnection then
		matchStateModeConnection:Disconnect()
		matchStateModeConnection = nil
	end
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		else
			connection()
		end
	end
	table.clear(connections)
	for i = #loadedModules, 1, -1 do
		local entry = loadedModules[i]
		local module = entry.module
		local stop = if typeof(module.destroy) == "function" then module.destroy else module.stop
		if typeof(stop) == "function" then
			local ok, reason = pcall(stop)
			if not ok then
				warn(`[SimulationClient] {entry.path} cleanup failed: {reason}`)
			end
		end
	end
	table.clear(loadedModules)
	for i = #startedCore, 1, -1 do
		local ok, reason = pcall(startedCore[i])
		if not ok then
			warn(`[SimulationClient] core cleanup failed: {reason}`)
		end
	end
	table.clear(startedCore)
end

script.Destroying:Connect(cleanup)

local function startCore(name: string, start: () -> (), stop: () -> ())
	table.insert(startedCore, stop)
	local ok, reason = pcall(start)
	if not ok then
		error(`[SimulationClient] {name}.start failed: {reason}`, 0)
	end
end

local systems: { any } = {
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
		path = "ReplicatedStorage.Shared.Game.Cosmetics.CosmeticEffects",
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
	{ name = "SplashdownCamera", parent = Presentation, method = "start" },
	{ name = "SplashEffects", parent = Presentation, method = "start" },
	{ name = "SplashdownAudio", parent = Presentation, method = "start" },
	{ name = "JumpPadVisuals", parent = Presentation, method = "start" },
	{ name = "BumperVisuals", parent = Presentation, method = "start" },
	{ name = "HazardVisuals", parent = Presentation, method = "start" },
	{ name = "HazardCarriers", parent = Presentation, method = "start" },
	{ name = "EmotePlayback", parent = Presentation, method = "start" },
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
	{ name = "ChargeAim", parent = Presentation, method = "start" },
	{ name = "WeaponAnimations", parent = Presentation, method = "start", intent = true },
}
if RunService:IsStudio() then
	table.insert(systems, { name = "DebugVisuals", parent = DebugModules, method = "start", combat = true, optional = true })
	table.insert(systems, { name = "ThrowPoseTuner", parent = DebugModules, method = "start", optional = true })
	table.insert(systems, { name = "CosmeticVFXGallery", parent = DebugModules, method = "start", optional = true })
	table.insert(systems, { name = "DevMatchSkip", parent = DebugModules, method = "start", optional = true })
end
local function systemPath(system: any): string
	return system.path or `{system.parent:GetFullName()}.{system.name}`
end

local function loadSystem(system: any): any
	local path = systemPath(system)
	local ok, module = pcall(function()
		if system.load then
			return system.load()
		end
		local child = system.parent:WaitForChild(system.name, 15)
		assert(child and child:IsA("ModuleScript"), `{path} must be a ModuleScript`)
		return require(child)
	end)
	if not ok then
		error(`[SimulationClient] {path} failed to load: {module}`, 0)
	end
	assert(typeof(module) == "table", `[SimulationClient] {path} must return a table`)
	if system.method then
		assert(typeof(module[system.method]) == "function", `[SimulationClient] {path}.{system.method} must be a function`)
	end
	if system.combat then
		assert(typeof(module.onEvent) == "function", `[SimulationClient] {path}.onEvent must be a function`)
	end
	if system.damage then
		assert(typeof(module[system.damage]) == "function", `[SimulationClient] {path}.{system.damage} must be a function`)
	end
	if system.intent then
		assert(typeof(module.onIntent) == "function", `[SimulationClient] {path}.onIntent must be a function`)
	end
	return module
end

local startupOk, startupError = pcall(function()
	ConfigReplication.startClient(LiveConfig.loadModules("arena"))
	Combat.setCameraEnabled(true)
	-- Loading every required module before starting presenters prevents a missing
	-- module from leaving an earlier presenter running during partial startup.
	for _, system in systems do
		if system.optional then
			local ok, module = pcall(loadSystem, system)
			if ok then
				system.module = module
			else
				warn(`[SimulationClient] Studio-only {systemPath(system)} unavailable: {module}`)
			end
		else
			system.module = loadSystem(system)
		end
	end
	startCore("AssistConfig", AssistConfig.start, AssistConfig.stop)
	startCore("CombatState", CombatState.start, CombatState.destroy)
	startCore("InputRouter", InputRouter.start, InputRouter.destroy)
	startCore("CameraAssist", CameraAssist.start, CameraAssist.stop)
	startCore("CombatInputSender", CombatInputSender.start, CombatInputSender.destroy)
	startCore("VoteCamera", VoteCamera.start, VoteCamera.destroy)
	for _, system in systems do
		local module = system.module
		if module == nil then
			continue
		end
		local path = systemPath(system)
		if system.method then
			table.insert(loadedModules, { module = module, path = path })
			local ok, reason = pcall(module[system.method])
			if not ok then
				if system.optional then
					warn(`[SimulationClient] Studio-only {path}.{system.method} failed: {reason}`)
					local stop = if typeof(module.destroy) == "function" then module.destroy else module.stop
					if typeof(stop) == "function" then
						pcall(stop)
					end
					table.remove(loadedModules)
					continue
				end
				error(`[SimulationClient] {path}.{system.method} failed: {reason}`, 0)
			end
		end
		if system.onLoaded then
			system.onLoaded(module)
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
	end
end)
if not startupOk then
	cleanup()
	ArenaLoadingClient.failStartup(script:GetFullName(), tostring(startupError))
	error(startupError, 0)
end
local function updateCombatInput()
	Combat.setInputEnabled(
		Players.LocalPlayer:GetAttribute("ArenaReady") == true
			and matchState ~= nil
			and matchState:GetAttribute("phase") == "Active"
			and GameModes.IsCombat(matchState:GetAttribute("modeId"))
	)
end

local function attachMatchState(folder: Folder)
	if matchStateConnection then
		matchStateConnection:Disconnect()
	end
	if matchStateModeConnection then
		matchStateModeConnection:Disconnect()
	end
	matchState = folder
	matchStateConnection = folder:GetAttributeChangedSignal("phase"):Connect(updateCombatInput)
	matchStateModeConnection = folder:GetAttributeChangedSignal("modeId"):Connect(updateCombatInput)
	updateCombatInput()
end

local function presentCombatEvent(event)
	for _, present in combatPresenters do
		present(event)
	end
	if Debug.CombatTrace and (event.kind == "Elim" or event.kind == "BallThrown") then
		print(`[Combat/client] {event.kind} {event.projectileId or ""}`)
	end
end

local wiringOk, wiringError = pcall(function()
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
end)
if not wiringOk then
	cleanup()
	ArenaLoadingClient.failStartup(script:GetFullName(), `event wiring failed: {wiringError}`)
	error(wiringError, 0)
end

ArenaLoadingClient.markSimulationReady()
