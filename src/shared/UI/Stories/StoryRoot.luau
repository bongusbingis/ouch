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
