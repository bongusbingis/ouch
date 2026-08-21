--!strict

local Players = game:GetService("Players")

-- Creates the container a React root mounts into.
--
-- React must never be given PlayerGui directly. Its reconciler clears the
-- container on first commit, and react-roblox implements that by destroying
-- every child -- which takes the engine's own TouchGui with it, and with it the
-- movement thumbstick and jump button. They do not come back: ControlModule only
-- rebuilds when its reference is nil, and a destroyed instance is still truthy.
--
-- Handing React a container of our own means the clear can only ever wipe our
-- own subtree.

local ReactRoot = {}

function ReactRoot.create(name: string): ScreenGui
	local container = Instance.new("ScreenGui")
	container.Name = name
	container.ResetOnSpawn = false
	container.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return container
end

return ReactRoot
