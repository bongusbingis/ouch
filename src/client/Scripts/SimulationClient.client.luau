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
local TargetingUI = require(Presentation:WaitForChild("TargetingUI"))
local UI = Client:WaitForChild("Modules"):WaitForChild("UI")
local MenuManager = require(UI:WaitForChild("MenuManager"))
local SidebarController = require(UI:WaitForChild("SidebarController"))
local QuestsController = require(UI:WaitForChild("QuestsController"))
local EconomyPrototypeUI = require(UI:WaitForChild("EconomyPrototypeUI"))
local EconomyStore = require(UI:WaitForChild("EconomyStore"))
local ShopController = require(UI:WaitForChild("ShopController"))
local InventoryController = require(UI:WaitForChild("InventoryController"))
local MatchHud = require(UI:WaitForChild("MatchHud"))
local DebugModules = Client:WaitForChild("Modules"):WaitForChild("Debug")
local DebugVisuals = require(DebugModules:WaitForChild("DebugVisuals"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

InputRouter.start()
BallVisuals.start()
DamageFeedback.start()
DeathEffects.start()
HammerVisuals.start()
TargetingUI.start()
EconomyPrototypeUI.mount()
MenuManager.start()
SidebarController.start()
EconomyStore.start()
QuestsController.start()
ShopController.start()
InventoryController.start()
MatchHud.start()
DebugVisuals.start()

Replica.RequestData()

-- TODO(ui): scoreboard — per-player scores replicate as a `MatchScore`
-- attribute on each Player (plus leaderstats.Elims). TODO(ui): killfeed —
-- subscribe MatchService.onEvent server-side and forward via a remote.

-- Tentative feedback only: client events can replay during resimulation, so
-- anything user-facing built on them must deduplicate (M3).
ServerAuthAdapter.onEvent(function(event)
	BallVisuals.onEvent(event)
	DamageFeedback.onEvent(event)
	HammerVisuals.onEvent(event)
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
