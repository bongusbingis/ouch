-- Reads ArenaService's authored-marker projection without depending on streamed geometry.
--!strict

local Workspace = game:GetService("Workspace")

return function(): Vector3
	local arena = Workspace:WaitForChild("Assets"):WaitForChild("Arena")
	local position = arena:GetAttribute("MapOriginPosition")
	while position == nil do
		arena:GetAttributeChangedSignal("MapOriginPosition"):Wait()
		position = arena:GetAttribute("MapOriginPosition")
	end
	assert(typeof(position) == "Vector3", "[ArenaOrigin] MapOriginPosition must be a Vector3")
	return position
end
