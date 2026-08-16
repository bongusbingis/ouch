local Players = game:GetService("Players")

local lobby = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby")
local NavigationController = require(lobby:WaitForChild("NavigationController"))
local NotificationController = require(lobby:WaitForChild("NotificationController"))
local PartyBackgroundController = require(lobby:WaitForChild("PartyBackgroundController"))
local PartyController = require(lobby:WaitForChild("PartyController"))

local screenGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")
local notifications = NotificationController.new(screenGui)

NavigationController.start(screenGui)
task.spawn(PartyBackgroundController.start)
task.spawn(PartyController.start, screenGui, notifications)
