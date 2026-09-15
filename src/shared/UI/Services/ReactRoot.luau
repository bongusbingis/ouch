-- Description: Creates and mounts React roots for the game's screens, including detached roots used for previews and stories.

--!strict

local Players = game:GetService("Players")

local ReactRoot = {}

local function create(
	name: string,
	screenInsets: Enum.ScreenInsets?,
	displayOrder: number?,
	viewportOverflow: boolean?
): ScreenGui
	local container = Instance.new("ScreenGui")
	container.Name = name
	container.ResetOnSpawn = false
	container.ScreenInsets = screenInsets or Enum.ScreenInsets.DeviceSafeInsets
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.DisplayOrder = displayOrder or 0
	if viewportOverflow then
		container.ClipToDeviceSafeArea = false
		container.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	end
	return container
end

function ReactRoot.create(
	name: string,
	screenInsets: Enum.ScreenInsets?,
	displayOrder: number?,
	viewportOverflow: boolean?
): ScreenGui
	local container = create(name, screenInsets, displayOrder, viewportOverflow)
	container.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return container
end

function ReactRoot.createDetached(name: string, screenInsets: Enum.ScreenInsets?, displayOrder: number?): ScreenGui
	return create(name, screenInsets, displayOrder)
end

return ReactRoot
