local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-roblox"))
local Replica = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
local EconomyStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore")
)
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)

local lobby = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby")
local PartyBackgroundController = require(lobby:WaitForChild("PartyBackgroundController"))
local PartyClient = require(lobby:WaitForChild("PartyClient"))
local LobbyApp = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LobbyApp"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local partyClient = PartyClient.new()
local background = PartyBackgroundController.start()
local root = ReactRoblox.createRoot(playerGui)

EconomyStore.start()
UIFeedback.start()
partyClient:start()
root:render(React.createElement(LobbyApp, { PartyClient = partyClient }))
Replica.RequestData()

script.Destroying:Connect(function()
	root:unmount()
	partyClient:destroy()
	if background then
		background:destroy()
	end
	EconomyStore.stop()
	UIFeedback.destroy()
end)
