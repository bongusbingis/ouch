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

local function create(name: string, screenInsets: Enum.ScreenInsets?, displayOrder: number?): ScreenGui
	local container = Instance.new("ScreenGui")
	container.Name = name
	container.ResetOnSpawn = false
	container.ScreenInsets = screenInsets or Enum.ScreenInsets.DeviceSafeInsets
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.DisplayOrder = displayOrder or 0
	return container
end

function ReactRoot.create(name: string, screenInsets: Enum.ScreenInsets?, displayOrder: number?): ScreenGui
	local container = create(name, screenInsets, displayOrder)
	container.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return container
end

function ReactRoot.createDetached(name: string, screenInsets: Enum.ScreenInsets?, displayOrder: number?): ScreenGui
	return create(name, screenInsets, displayOrder)
end

return ReactRoot
