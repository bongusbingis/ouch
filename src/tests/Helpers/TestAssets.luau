-- Description: Fail-fast lookups for Studio-authored assets inside specs, surfacing a missing asset as a named failure instead of hanging the cloud task.

--!strict

local TestAssets = {}

function TestAssets.get(root: Instance, ...: string): Instance
	local current = root
	for _, name in { ... } do
		local child = current:FindFirstChild(name)
		assert(child ~= nil, `[TestAssets] missing "{name}" under {current:GetFullName()}`)
		current = child
	end
	return current
end

return TestAssets
