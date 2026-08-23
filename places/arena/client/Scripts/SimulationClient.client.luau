local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
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
Combat.setInputEnabled(true)

AssistConfig.start()
-- Before the arm and animation layers: both read its snapshot, and the input
-- sender pushes presses into it.
CombatState.start()
ArmIK.start()
InputRouter.start()
CameraAssist.start()
BallVisuals.start()
DamageFeedback.start()
DeathEffects.start()
HammerVisuals.start()
SplatEffects.start()
MatchAudio.start()
PlayerHighlights.start()
JumpPadVisuals.start()
RotatingPlatforms.load()
PlatformRider.start()
-- Started last: it waits on the authored Arena.MapOrigin, so a missing part
-- surfaces as an infinite-yield warning without stalling the modules above.
VoteCamera.start()
DebugVisuals.start()
ThrowPoseTuner.start()
ChargeAim.start()

-- Presentation only. These are the server's authoritative events, replayed here
-- purely to drive effects; nothing in this path decides an outcome.
Network.on("CombatSimEvent", function(events)
	for _, event in events do
		BallVisuals.onEvent(event)
		HammerVisuals.onEvent(event)
		SplatEffects.onEvent(event)
		GameAudio.onEvent(event)
		DebugVisuals.onEvent(event)
		if Debug.CombatTrace and (event.kind == "Elim" or event.kind == "BallThrown") then
			print(`[Combat/client] {event.kind} {event.projectileId or ""}`)
		end
	end
end)

Network.on("DamageFeedback", function(event)
	DamageFeedback.onEvent(event)
	DeathEffects.notifyElim(event)
end)

WeaponAnimations.start()
CombatInputSender.onIntent(WeaponAnimations.onIntent)
CombatInputSender.start()
