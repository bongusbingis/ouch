-- Name: LobbyClient.client.luau
-- Author: Jack C.
-- Description: Lobby client entry point: starts the party adapter, background controller, teleport presentation, and mounts the lobby React root.
-- Created: 2026-08-15

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-roblox"))
local Replica = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
local EconomyStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore")
)
local ShopClient = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("ShopClient")
)
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local ConfigReplication = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("ConfigReplication")
)

local lobby = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby")
local PartyBackgroundController = require(lobby:WaitForChild("PartyBackgroundController"))
local PartyClient = require(lobby:WaitForChild("PartyClient"))
local TeleportPresentationClient = require(lobby:WaitForChild("TeleportPresentationClient"))
local ReactRoot = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("ReactRoot")
)
local LobbyApp = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LobbyApp"))

local partyClient = PartyClient.new()
local teleportPresentation = TeleportPresentationClient.start(function()
	partyClient:setTeleportPresentationReady()
end)
local background = PartyBackgroundController.start()
local container = ReactRoot.create("LobbyRoot")
local root = ReactRoblox.createRoot(container)

ConfigReplication.startClient({
	GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes")),
	Matchmaking = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config")),
	Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop")),
	Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates")),
})
EconomyStore.start()
ShopClient.start()
UIFeedback.start()
partyClient:start()
root:render(React.createElement(LobbyApp, {
	PartyClient = partyClient,
	ShopClient = ShopClient,
	OnPresented = function()
		ReplicatedFirst:SetAttribute("ReactLoadingPresented", true)
	end,
}))
Replica.RequestData()

script.Destroying:Connect(function()
	root:unmount()
	container:Destroy()
	partyClient:destroy()
	teleportPresentation.destroy()
	if background then
		background:destroy()
	end
	EconomyStore.stop()
	ShopClient.stop()
	UIFeedback.destroy()
end)
