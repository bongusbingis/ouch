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
local PlatformRider = require(Client:WaitForChild("Modules"):WaitForChild("Movement"):WaitForChild("PlatformRider"))
local Presentation = Client:WaitForChild("Modules"):WaitForChild("Presentation")
local BallVisuals = require(Presentation:WaitForChild("BallVisuals"))
local DamageFeedback = require(Presentation:WaitForChild("DamageFeedback"))
local DeathEffects = require(Presentation:WaitForChild("DeathEffects"))
local HammerVisuals = require(Presentation:WaitForChild("HammerVisuals"))
local SplatEffects = require(Presentation:WaitForChild("SplatEffects"))
local MatchAudio = require(Presentation:WaitForChild("MatchAudio"))
local GameAudio = require(Presentation:WaitForChild("GameAudio"))
local JumpPadVisuals = require(Presentation:WaitForChild("JumpPadVisuals"))
local PlayerHighlights = require(Presentation:WaitForChild("PlayerHighlights"))
local WeaponAnimations = require(Presentation:WaitForChild("WeaponAnimations"))
local CombatState = require(Presentation:WaitForChild("CombatState"))
local ArmIK = require(Presentation:WaitForChild("ArmIK"))
local VoteCamera = require(Presentation:WaitForChild("VoteCamera"))
local DebugModules = Client:WaitForChild("Modules"):WaitForChild("Debug")
local ThrowPoseTuner = require(DebugModules:WaitForChild("ThrowPoseTuner"))
local DebugVisuals = require(DebugModules:WaitForChild("DebugVisuals"))
local ChargeAim = require(Presentation:WaitForChild("ChargeAim"))

local RotatingPlatforms = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("RotatingPlatforms")
)
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local ArenaLoadingClient = require(Client:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ArenaLoadingClient"))

local connections = {}
local optionalSystems = {}

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
-- The arena is the only place that turns combat on. The lobby leaves it off and
-- therefore keeps a normal cursor for its menus, with no lobby-side code needed.
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
Combat.setCameraEnabled(true)
Combat.setInputEnabled(false)

AssistConfig.start()
-- Before the arm and animation layers: both read its snapshot, and the input
-- sender pushes presses into it.
CombatState.start()
InputRouter.start()
CameraAssist.start()
CombatInputSender.start()
VoteCamera.start()
ArenaLoadingClient.markSimulationReady()

startOptional("ArmIK", ArmIK.start)
startOptional("BallVisuals", BallVisuals.start)
startOptional("DamageFeedback", DamageFeedback.start)
startOptional("DeathEffects", DeathEffects.start)
startOptional("HammerVisuals", HammerVisuals.start)
startOptional("SplatEffects", SplatEffects.start)
startOptional("MatchAudio", MatchAudio.start)
startOptional("PlayerHighlights", PlayerHighlights.start)
startOptional("JumpPadVisuals", JumpPadVisuals.start)
startOptional("RotatingPlatforms", RotatingPlatforms.load)
startOptional("PlatformRider", PlatformRider.start)
startOptional("DebugVisuals", DebugVisuals.start)
startOptional("ThrowPoseTuner", ThrowPoseTuner.start)
startOptional("ChargeAim", ChargeAim.start)
if startOptional("WeaponAnimations", WeaponAnimations.start) then
	table.insert(connections, CombatInputSender.onIntent(WeaponAnimations.onIntent))
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

-- Presentation only. These are the server's authoritative events, replayed here
-- purely to drive effects; nothing in this path decides an outcome.
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
			GameAudio.onEvent(event)
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
