-- One cached scan per immutable course assembly and feature; no per-part loops.
--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttributeRules = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures"):WaitForChild("AttributeRules")
)
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
function FeatureParts.number(part: Instance, key: string, fallback: number): number
	assert(AttributeRules.isFeatureValueKey(key), `[FeatureParts] {key} is not a registered feature value key`)
	local value = part:GetAttribute(key)
	if value == nil then
		return fallback
	end
	local reason = AttributeRules.checkPresentValue(part:GetFullName(), key, value)
	assert(reason == nil, `[FeatureParts] {reason}`)
	return value :: number
end
function FeatureParts.axis(part: Instance, key: string, fallback: string): Vector3
	assert(AttributeRules.isFeatureValueKey(key), `[FeatureParts] {key} is not a registered feature value key`)
	local value = part:GetAttribute(key)
	value = if value == nil then fallback else value
	local reason = AttributeRules.checkPresentValue(part:GetFullName(), key, value)
	assert(reason == nil, `[FeatureParts] {reason}`)
	return if value == "X" then Vector3.xAxis elseif value == "Z" then Vector3.zAxis else Vector3.yAxis
end
return FeatureParts
