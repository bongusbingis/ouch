-- One cached scan per immutable course assembly and feature; no per-part loops.
--!strict
local Workspace = game:GetService("Workspace")
local FeatureParts = {}
local cache: { [Model]: { [string]: { BasePart } } } = {}
function FeatureParts.collect(groups: { Instance }, attribute: string): { BasePart }
	for assembly in cache do
		if not assembly:IsDescendantOf(Workspace) then
			cache[assembly] = nil
		end
	end
	local result = {}
	for _, group in groups do
		local assembly = group:FindFirstChild("Assembly")
		if not assembly or not assembly:IsA("Model") then
			continue
		end
		cache[assembly] = cache[assembly] or {}
		local found = cache[assembly][attribute]
		if not found then
			found = {}
			for _, part in assembly:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute(attribute) == true then
					table.insert(found, part)
				end
			end
			cache[assembly][attribute] = found
		end
		for _, part in found do
			if part:IsDescendantOf(assembly) then
				table.insert(result, part)
			end
		end
	end
	return result
end
function FeatureParts.number(part: Instance, key: string, fallback: number, minimum: number, maximum: number): number
	local v = part:GetAttribute(key)
	if typeof(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
		return fallback
	end
	return math.clamp(v, minimum, maximum)
end
function FeatureParts.axis(value: any): Vector3
	return if value == "X" then Vector3.xAxis elseif value == "Z" then Vector3.zAxis else Vector3.yAxis
end
return FeatureParts
