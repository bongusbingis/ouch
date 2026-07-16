--!strict
-- Fail-fast lookups for Studio-authored assets inside specs. WaitForChild on a
-- missing asset would hang the cloud task until its 5-minute cap; FindFirstChild
-- plus assert surfaces the same setup problem as an immediate, named failure.

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
