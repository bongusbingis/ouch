local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Debug"))

local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local InputRouter = require(Client:WaitForChild("Modules"):WaitForChild("Input"):WaitForChild("InputRouter"))
local Presentation = Client:WaitForChild("Modules"):WaitForChild("Presentation")
local BallVisuals = require(Presentation:WaitForChild("BallVisuals"))
local DamageFeedback = require(Presentation:WaitForChild("DamageFeedback"))
local HammerVisuals = require(Presentation:WaitForChild("HammerVisuals"))
local TargetingUI = require(Presentation:WaitForChild("TargetingUI"))
local UI = Client:WaitForChild("Modules"):WaitForChild("UI")
local MenuManager = require(UI:WaitForChild("MenuManager"))
local DebugModules = Client:WaitForChild("Modules"):WaitForChild("Debug")
local DebugVisuals = require(DebugModules:WaitForChild("DebugVisuals"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))

InputRouter.start()
BallVisuals.start()
DamageFeedback.start()
HammerVisuals.start()
TargetingUI.start()
MenuManager.start()
DebugVisuals.start()

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

ServerAuthAdapter.start()
