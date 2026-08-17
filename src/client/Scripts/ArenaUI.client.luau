--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local ArenaApp = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ArenaApp"))

local root = ReactRoblox.createRoot(Players.LocalPlayer:WaitForChild("PlayerGui"))

UIFeedback.start()
root:render(React.createElement(ArenaApp))

script.Destroying:Connect(function()
	root:unmount()
	UIFeedback.destroy()
end)
