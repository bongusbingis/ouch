-- Description: Arena client gameplay startup. Local failures are diagnostic-only so server admission and healthy systems can continue.
--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local BOOTSTRAP_WAIT_SECONDS = 5
local warned: { [string]: boolean } = {}
local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[SimulationClient] " .. message)
end
local function safeCall(key: string, callback: () -> any): (boolean, any)
	local ok, result = pcall(callback)
	if not ok then
		warnOnce(key, key .. " failed: " .. tostring(result))
	end
	return ok, result
end

local deadline = os.clock() + BOOTSTRAP_WAIT_SECONDS
while ReplicatedFirst:GetAttribute("ReactLoadingPresented") ~= true and os.clock() < deadline do
	task.wait()
end
if ReplicatedFirst:GetAttribute("ReactLoadingPresented") ~= true then
	warnOnce("ReactLoadingPresented", "React loading presentation timed out; continuing")
end

local function child(parent: Instance?, name: string): Instance?
	return if parent then parent:FindFirstChild(name) else nil
end
local function module(path: string, parent: Instance?, name: string): any
	local value = child(parent, name)
	if value == nil then
		warnOnce(path, path .. " is missing")
		return nil
	end
	if not value:IsA("ModuleScript") then
		warnOnce(path, path .. " must be a ModuleScript")
		return nil
	end
	local ok, result = safeCall(path, function()
		return require(value)
	end)
	if not ok or typeof(result) ~= "table" then
		if ok then
			warnOnce(path, path .. " must return a table")
		end
		return nil
	end
	return result
end

local player = Players.LocalPlayer
local clientModules = child(child(child(player, "PlayerScripts"), "Client"), "Modules")
local inputModules = child(clientModules, "Input")
local presentation = child(clientModules, "Presentation")
local movement = child(clientModules, "Movement")
local uiModules = child(clientModules, "UI")
local debugModules = if RunService:IsStudio() then child(clientModules, "Debug") else nil
local configRoot = child(ReplicatedStorage, "Config")
local shared = child(ReplicatedStorage, "Shared")
local sharedGame = child(shared, "Game")
local mapFeatures = child(sharedGame, "MapFeatures")

local connections: { any } = {}
local started: { any } = {}
local combatPresenters: { any } = {}
local damagePresenters: { any } = {}
local combat: any = nil
local gameModes: any = nil
local debugConfig: any = nil
local loadingClient: any = nil
local matchState: Folder? = nil
local phaseConnection: RBXScriptConnection? = nil
local modeConnection: RBXScriptConnection? = nil
local cleaned = false
local markedReady = false
local simulationAttemptFinished = false

local function stop(entry: any)
	if not entry.active then
		return
	end
	entry.active = false
	local cleanup = if typeof(entry.module.destroy) == "function" then entry.module.destroy else entry.module.stop
	if typeof(cleanup) == "function" then
		safeCall(entry.path .. " cleanup", cleanup)
	end
end
local function disconnect(connection: any)
	if typeof(connection) == "RBXScriptConnection" then
		safeCall("event cleanup", function()
			connection:Disconnect()
		end)
	elseif typeof(connection) == "function" then
		safeCall("event cleanup", connection)
	end
end
local function setInput(enabled: boolean)
	if typeof(combat) ~= "table" or typeof(combat.setInputEnabled) ~= "function" then
		warnOnce("Combat.setInputEnabled", "combat input control is unavailable")
		return
	end
	safeCall("Combat.setInputEnabled", function()
		combat.setInputEnabled(enabled)
	end)
end
local function cleanup()
	if cleaned then
		return
	end
	cleaned = true
	setInput(false)
	if phaseConnection then
		disconnect(phaseConnection)
	end
	if modeConnection then
		disconnect(modeConnection)
	end
	for _, connection in connections do
		disconnect(connection)
	end
	table.clear(connections)
	for index = #started, 1, -1 do
		stop(started[index])
	end
	table.clear(started)
	table.clear(combatPresenters)
	table.clear(damagePresenters)
end
script.Destroying:Connect(cleanup)

local function updateInput()
	local eligible = false
	if
		gameModes ~= nil
		and typeof(gameModes.IsCombat) == "function"
		and matchState ~= nil
		and matchState:GetAttribute("phase") == "Active"
	then
		local ok, result = safeCall("GameModes.IsCombat", function()
			return gameModes.IsCombat(matchState:GetAttribute("modeId"))
		end)
		eligible = ok and result == true
	end
	setInput(Players.LocalPlayer:GetAttribute("ArenaReady") == true and eligible)
end
local function markSimulationReady()
	if
		cleaned
		or not simulationAttemptFinished
		or markedReady
		or loadingClient == nil
		or typeof(loadingClient.markSimulationReady) ~= "function"
	then
		return
	end
	markedReady = true
	safeCall("ArenaLoadingClient.markSimulationReady", loadingClient.markSimulationReady)
end
local function addConnection(key: string, callback: () -> any)
	local ok, connection = safeCall(key, callback)
	if ok and connection ~= nil then
		if cleaned then
			disconnect(connection)
		else
			table.insert(connections, connection)
		end
	end
end
local function attachMatchState(folder: Folder)
	if phaseConnection then
		disconnect(phaseConnection)
	end
	if modeConnection then
		disconnect(modeConnection)
	end
	matchState = folder
	local ok, connection = safeCall("MatchState.phase wiring", function()
		return folder:GetAttributeChangedSignal("phase"):Connect(updateInput)
	end)
	phaseConnection = if ok then connection else nil
	ok, connection = safeCall("MatchState.mode wiring", function()
		return folder:GetAttributeChangedSignal("modeId"):Connect(updateInput)
	end)
	modeConnection = if ok then connection else nil
	updateInput()
end
local function present(list: { any }, event: any)
	for index = #list, 1, -1 do
		local entry = list[index]
		local ok, reason = pcall(entry.callback, event)
		if not ok then
			warnOnce(entry.path .. " callback", entry.path .. " callback failed: " .. tostring(reason))
			stop(entry.lifecycle)
			table.remove(list, index)
		end
	end
end
local function presentCombat(event: any)
	present(combatPresenters, event)
	if
		debugConfig
		and debugConfig.CombatTrace
		and typeof(event) == "table"
		and (event.kind == "Elim" or event.kind == "BallThrown")
	then
		print("[Combat/client] " .. event.kind .. " " .. tostring(event.projectileId or ""))
	end
end
local function start(path: string, parent: Instance?, name: string, method: string): any
	local value = module(path, parent, name)
	if value == nil or cleaned then
		return nil
	end
	local callback = value[method]
	if typeof(callback) ~= "function" then
		warnOnce(path, path .. "." .. method .. " must be a function")
		return nil
	end
	local ok = safeCall(path .. "." .. method, callback)
	local entry = { path = path, module = value, active = true }
	if not ok or cleaned then
		stop(entry)
		return nil
	end
	table.insert(started, entry)
	return entry
end

local systems: { any } = {
	{ name = "ArmIK", parent = presentation, method = "start" },
	{ name = "BallVisuals", parent = presentation, method = "start", combat = true },
	{ name = "DamageFeedback", parent = presentation, method = "start", damage = "onEvent" },
	{ name = "DeathEffects", parent = presentation, method = "start", damage = "notifyElim" },
	{ name = "HammerVisuals", parent = presentation, method = "start", combat = true },
	{ name = "SplatEffects", parent = presentation, method = "start", combat = true },
	{ name = "CosmeticEffects", parent = child(sharedGame, "Cosmetics"), method = "start", combat = true },
	{ name = "MatchAudio", parent = presentation, method = "start" },
	{ name = "GameAudio", parent = presentation, combat = true },
	{ name = "PlayerHighlights", parent = presentation, method = "start" },
	{ name = "SplashdownCamera", parent = presentation, method = "start" },
	{ name = "SplashEffects", parent = presentation, method = "start" },
	{ name = "SplashdownAudio", parent = presentation, method = "start" },
	{ name = "JumpPadVisuals", parent = presentation, method = "start" },
	{ name = "BumperVisuals", parent = presentation, method = "start" },
	{ name = "CoinVisuals", parent = presentation, method = "start" },
	{ name = "HazardCarriers", parent = presentation, method = "start" },
	{ name = "EmotePlayback", parent = presentation, method = "start" },
	{ name = "FanAirflow", parent = presentation, method = "start" },
	{ name = "PlatformRider", parent = movement, method = "start" },
	{ name = "ChargeAim", parent = presentation, method = "start" },
	{ name = "WeaponAnimations", parent = presentation, method = "start", intent = true },
}
if RunService:IsStudio() then
	table.insert(systems, { name = "DebugVisuals", parent = debugModules, method = "start", combat = true })
	table.insert(systems, { name = "ThrowPoseTuner", parent = debugModules, method = "start" })
	table.insert(systems, { name = "CosmeticVFXGallery", parent = debugModules, method = "start" })
	table.insert(systems, { name = "DevMatchSkip", parent = debugModules, method = "start" })
end

-- Establish the render registries before effects start. Each startup remains isolated.
start("Client.Modules.Presentation.HazardVisuals", presentation, "HazardVisuals", "start")
start(
	"ReplicatedStorage.Shared.Game.MapFeatures.RotatingPlatforms",
	mapFeatures,
	"RotatingPlatforms",
	"startClientMover"
)
start("Client.Modules.Presentation.PhysicalHazardVisuals", presentation, "PhysicalHazardVisuals", "start")
start("Client.Modules.Presentation.MotionHazardVisuals", presentation, "MotionHazardVisuals", "start")

for _, system in systems do
	task.spawn(function()
		local name, parent, method = system.name, system.parent, system.method
		local path = ((parent and parent:GetFullName()) or "unavailable") .. "." .. name
		local value = module(path, parent, name)
		if value == nil or cleaned then
			return
		end
		for _, requirement in
			{ { system.combat, "onEvent" }, { system.damage, system.damage }, { system.intent, "onIntent" } }
		do
			if requirement[1] and typeof(value[requirement[2]]) ~= "function" then
				warnOnce(path, path .. "." .. requirement[2] .. " must be a function")
				return
			end
		end
		local entry: any
		if method then
			entry = start(path, parent, name, method)
		else
			entry = { path = path, module = value, active = true }
			if cleaned then
				stop(entry)
				return
			else
				table.insert(started, entry)
			end
		end
		if entry == nil then
			return
		end
		if system.combat then
			table.insert(combatPresenters, { path = path, callback = value.onEvent, lifecycle = entry })
		end
		if system.damage then
			table.insert(damagePresenters, { path = path, callback = value[system.damage], lifecycle = entry })
		end
		if system.intent then
			task.spawn(function()
				local sender = module("Client.Modules.Input.CombatInputSender", inputModules, "CombatInputSender")
				if sender and typeof(sender.onIntent) == "function" then
					addConnection(path .. " intent wiring", function()
						return sender.onIntent(value.onIntent)
					end)
				else
					warnOnce(path .. " intent", "CombatInputSender.onIntent is unavailable")
				end
			end)
		end
	end)
end

task.spawn(function()
	-- Authoritative combat keeps its original order. Independent presentation is above.
	local liveConfig = module("ReplicatedStorage.Config.LiveConfig", configRoot, "LiveConfig")
	local configReplication = module(
		"ReplicatedStorage.Shared.Game.Adapters.ConfigReplication",
		child(sharedGame, "Adapters"),
		"ConfigReplication"
	)
	if
		liveConfig
		and configReplication
		and typeof(liveConfig.loadModules) == "function"
		and typeof(configReplication.startClient) == "function"
	then
		safeCall("ConfigReplication.startClient", function()
			configReplication.startClient(liveConfig.loadModules("arena"))
		end)
	else
		warnOnce("ConfigReplication.startClient", "configuration startup functions are unavailable")
	end
	start("Client.Modules.Input.AssistConfig", inputModules, "AssistConfig", "start")
	start("Client.Modules.Presentation.CombatState", presentation, "CombatState", "start")
	start("Client.Modules.Input.InputRouter", inputModules, "InputRouter", "start")
	start("Client.Modules.Input.CombatInputSender", inputModules, "CombatInputSender", "start")
	simulationAttemptFinished = true
	markSimulationReady()
end)
task.spawn(function()
	start("Client.Modules.Input.CameraAssist", inputModules, "CameraAssist", "start")
end)
task.spawn(function()
	start("Client.Modules.Presentation.VoteCamera", presentation, "VoteCamera", "start")
end)

task.spawn(function()
	gameModes = module("ReplicatedStorage.Config.Gameplay.GameModes", child(configRoot, "Gameplay"), "GameModes")
	debugConfig = module("ReplicatedStorage.Config.Infra.Debug", child(configRoot, "Infra"), "Debug")
	if not cleaned then
		updateInput()
	end
end)
task.spawn(function()
	local playerModule = module("StarterPlayer.PlayerModule", StarterPlayer, "PlayerModule")
	if cleaned then
		return
	end
	if playerModule and typeof(playerModule.Combat) == "table" then
		combat = playerModule.Combat
		if typeof(combat.setCameraEnabled) == "function" then
			safeCall("Combat.setCameraEnabled", function()
				combat.setCameraEnabled(true)
			end)
		end
		setInput(false)
		updateInput()
	else
		warnOnce("StarterPlayer.PlayerModule.Combat", "combat input module is unavailable")
	end
end)

addConnection("ArenaReady wiring", function()
	return Players.LocalPlayer:GetAttributeChangedSignal("ArenaReady"):Connect(updateInput)
end)
local existingMatchState = ReplicatedStorage:FindFirstChild("MatchState")
if existingMatchState and existingMatchState:IsA("Folder") then
	attachMatchState(existingMatchState)
end
addConnection("MatchState added wiring", function()
	return ReplicatedStorage.ChildAdded:Connect(function(value)
		if value.Name == "MatchState" and value:IsA("Folder") then
			attachMatchState(value)
		end
	end)
end)
task.spawn(function()
	local network = module("ReplicatedStorage.Shared.Network", shared, "Network")
	if cleaned then
		return
	end
	if network == nil or typeof(network.on) ~= "function" then
		warnOnce("Network.on", "combat event wiring is unavailable")
		return
	end
	addConnection("CombatSimEvent wiring", function()
		return network.on("CombatSimEvent", function(events)
			safeCall("CombatSimEvent callback", function()
				if typeof(events) == "table" then
					for _, event in events do
						presentCombat(event)
					end
				end
			end)
		end)
	end)
	addConnection("CombatFeed wiring", function()
		return network.on("CombatFeed", function(event)
			safeCall("CombatFeed callback", function()
				if typeof(event) == "table" and event.kind == "Elim" then
					presentCombat(event)
				end
			end)
		end)
	end)
	addConnection("DamageFeedback wiring", function()
		return network.on("DamageFeedback", function(event)
			safeCall("DamageFeedback callback", function()
				present(damagePresenters, event)
			end)
		end)
	end)
end)
task.spawn(function()
	loadingClient = module("Client.Modules.UI.ArenaLoadingClient", uiModules, "ArenaLoadingClient")
	if cleaned then
		return
	end
	if loadingClient then
		markSimulationReady()
	else
		warnOnce("ArenaLoadingClient.markSimulationReady", "simulation readiness marker is unavailable")
	end
end)
task.delay(BOOTSTRAP_WAIT_SECONDS, function()
	simulationAttemptFinished = true
	markSimulationReady()
end)
