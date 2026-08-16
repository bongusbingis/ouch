local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
local EconomyStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore")
)

local lobby = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby")
local NavigationController = require(lobby:WaitForChild("NavigationController"))
local NotificationController = require(lobby:WaitForChild("NotificationController"))
local InventoryController = require(lobby:WaitForChild("InventoryController"))
local PartyBackgroundController = require(lobby:WaitForChild("PartyBackgroundController"))
local PartyController = require(lobby:WaitForChild("PartyController"))

local screenGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")
local notifications = NotificationController.new(screenGui)

NavigationController.start(screenGui)
EconomyStore.start()
task.spawn(InventoryController.start, screenGui, notifications)
task.spawn(PartyBackgroundController.start)
task.spawn(PartyController.start, screenGui, notifications)
Replica.RequestData()
