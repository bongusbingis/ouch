-- Name: StoryRoot.luau
-- Author: Jack C.
-- Description: Mounts a story element into a target instance and returns the unmount function every story uses.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))

return function(target: Instance, element: any): () -> ()
	local root = ReactRoblox.createRoot(target)
	root:render(element)
	return function()
		root:unmount()
	end
end
