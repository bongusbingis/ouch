-- One cached scan per immutable course assembly and feature; no per-part loops.
--!strict
local Workspace = game:GetService("Workspace")
local FeatureParts = {}
local cache: { [Model]: { [string]: { BasePart } } } = {}
function FeatureParts.collect(groups: { Instance }, attribute: string): { BasePart }
	for group in cache do
		if not group:IsDescendantOf(Workspace) then
			cache[group] = nil
		end
	end
	local result = {}
	for _, group in groups do
		cache[group] = cache[group] or {}
		local found = cache[group][attribute]
		if not found then
			found = {}
			if group:IsA("BasePart") and group:GetAttribute(attribute) == true then
				table.insert(found, group)
			end
			for _, part in group:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute(attribute) == true then
					table.insert(found, part)
				end
			end
			cache[group][attribute] = found
		end
		for _, part in found do
			if part == group or part:IsDescendantOf(group) then
				table.insert(result, part)
			end
		end
	end
	return result
end
function FeatureParts.number(part: Instance, key: string, fallback: number, minimum: number, maximum: number): number
	local v = part:GetAttribute(key)
	if typeof(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
		if part:FindFirstAncestor("SplashdownCourse") then
			assert(false, `[FeatureParts] {part:GetFullName()}.{key} must be a finite number`)
		end
		return fallback
	end
	return math.clamp(v, minimum, maximum)
end
function FeatureParts.axis(value: any): Vector3
	if value ~= nil and value ~= "X" and value ~= "Y" and value ~= "Z" then
		assert(false, "[FeatureParts] axis must be X, Y, or Z")
	end
	return if value == "X" then Vector3.xAxis elseif value == "Z" then Vector3.zAxis else Vector3.yAxis
end
return FeatureParts
