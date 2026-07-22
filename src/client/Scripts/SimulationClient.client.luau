local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Replica = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Debug"))

local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local InputRouter = require(Client:WaitForChild("Modules"):WaitForChild("Input"):WaitForChild("InputRouter"))
local Presentation = Client:WaitForChild("Modules"):WaitForChild("Presentation")
local BallVisuals = require(Presentation:WaitForChild("BallVisuals"))
local DamageFeedback = require(Presentation:WaitForChild("DamageFeedback"))
local DeathEffects = require(Presentation:WaitForChild("DeathEffects"))
local HammerVisuals = require(Presentation:WaitForChild("HammerVisuals"))
local SplatEffects = require(Presentation:WaitForChild("SplatEffects"))
local TargetingUI = require(Presentation:WaitForChild("TargetingUI"))
local UI = Client:WaitForChild("Modules"):WaitForChild("UI")
local MenuManager = require(UI:WaitForChild("MenuManager"))
local SidebarController = require(UI:WaitForChild("SidebarController"))
local QuestsController = require(UI:WaitForChild("QuestsController"))
local UIResolver = require(UI:WaitForChild("UIResolver"))
local EconomyStore = require(UI:WaitForChild("EconomyStore"))
local ShopController = require(UI:WaitForChild("ShopController"))
local InventoryController = require(UI:WaitForChild("InventoryController"))
local LeaderboardController = require(UI:WaitForChild("LeaderboardController"))
local MatchHud = require(UI:WaitForChild("MatchHud"))
local CooldownIndicator = require(UI:WaitForChild("CooldownIndicator"))
local DebugModules = Client:WaitForChild("Modules"):WaitForChild("Debug")
local DebugVisuals = require(DebugModules:WaitForChild("DebugVisuals"))
local AnalyticsModules = Client:WaitForChild("Modules"):WaitForChild("Analytics")
local AnalyticsReporter = require(AnalyticsModules:WaitForChild("AnalyticsReporter"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local function startCmdr()
	local player = Players.LocalPlayer
	while player:GetAttribute("CmdrAccess") == nil do
		task.wait()
	end
	if player:GetAttribute("CmdrAccess") ~= true then
		return
	end

	local root = ReplicatedStorage:WaitForChild("CmdrClient")
	while root:GetAttribute("SplatBrawlReady") ~= true do
		task.wait()
	end
	local cmdr = require(root)
	cmdr.Registry:RegisterHook("BeforeRun", function()
		return nil
	end)
	cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
	cmdr:SetPlaceName("Splat Brawl")
end

InputRouter.start()
BallVisuals.start()
DamageFeedback.start()
DeathEffects.start()
HammerVisuals.start()
SplatEffects.start()
TargetingUI.start()
UIResolver.mount()
MenuManager.start()
AnalyticsReporter.start()
SidebarController.start()
EconomyStore.start()
QuestsController.start()
ShopController.start()
InventoryController.start()
LeaderboardController.start()
MatchHud.start()
CooldownIndicator.start()
DebugVisuals.start()
task.spawn(startCmdr)

Replica.RequestData()

-- TODO(ui): killfeed — subscribe MatchService.onEvent server-side and forward
-- via a remote.

-- Tentative feedback only: client events can replay during resimulation, so
-- anything user-facing built on them must deduplicate (M3).
ServerAuthAdapter.onEvent(function(event)
	BallVisuals.onEvent(event)
	DamageFeedback.onEvent(event)
	HammerVisuals.onEvent(event)
	SplatEffects.onEvent(event)
	DebugVisuals.onEvent(event)
	if Debug.CombatTrace and (event.kind == "Elim" or event.kind == "BallThrown") then
		print(`[Combat/client] {event.kind} {event.projectileId or ""}`)
	end
end)

Network.on("DamageFeedback", function(event)
	DamageFeedback.onEvent(event)
	DeathEffects.notifyElim(event)
end)

ServerAuthAdapter.start()
