--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local ArenaApp = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ArenaApp"))

local root = ReactRoblox.createRoot(Players.LocalPlayer:WaitForChild("PlayerGui"))

UIFeedback.start()
root:render(React.createElement(ArenaApp))

-- Reported only once the arena UI is mounted: the server holds the mode vote
-- until arriving clients say this, so it must not fire before the vote could be
-- rendered.
Network.fireServer("ArenaClientReady")

script.Destroying:Connect(function()
	root:unmount()
	UIFeedback.destroy()
end)
