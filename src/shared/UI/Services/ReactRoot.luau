-- Name: ReactRoot.luau
-- Author: Jack C.
-- Description: Creates and mounts React roots for the game's screens, including detached roots used for previews and stories.
-- Created: 2026-08-20

--!strict

local Players = game:GetService("Players")

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
