--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local ReactRoot = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("ReactRoot")
)
local ArenaApp = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ArenaApp"))

local container = ReactRoot.create("ArenaRoot")
local root = ReactRoblox.createRoot(container)

UIFeedback.start()
root:render(React.createElement(ArenaApp))

-- Reported only once the arena UI is mounted: the server holds the mode vote
-- until arriving clients say this, so it must not fire before the vote could be
-- rendered. Rendering is scheduled onto the next frame in React, so a direct
-- remote send here races the mount and can open the vote before the player sees it.
local firedReady = false
local function sendReady()
	if firedReady then
		return
	end
	firedReady = true
	Network.fireServer("ArenaClientReady")
end

RunService.RenderStepped:Wait()
sendReady()

script.Destroying:Connect(function()
	root:unmount()
	container:Destroy()
	UIFeedback.destroy()
end)
