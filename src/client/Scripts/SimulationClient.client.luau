local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local InputRouter = require(Client:WaitForChild("Modules"):WaitForChild("Input"):WaitForChild("InputRouter"))
local Presentation = Client:WaitForChild("Modules"):WaitForChild("Presentation")
local BallVisuals = require(Presentation:WaitForChild("BallVisuals"))
local TargetingUI = require(Presentation:WaitForChild("TargetingUI"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))

InputRouter.start()
BallVisuals.start()
TargetingUI.start()

-- Tentative feedback only: client events can replay during resimulation, so
-- anything user-facing built on them must deduplicate (M3).
ServerAuthAdapter.onEvent(function(event)
	BallVisuals.onEvent(event)
	if event.kind == "Elim" or event.kind == "BallThrown" then
		print(`[Combat/client] {event.kind} {event.projectileId or ""}`)
	end
end)

ServerAuthAdapter.start()
