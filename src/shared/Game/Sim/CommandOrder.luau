-- Canonical command ordering is independent of arrival order, including duplicate action kinds.
--!strict

local SimTypes = require(script.Parent.SimTypes)
local SimUtil = require(script.Parent.SimUtil)

local CommandOrder = {}

local function compare(a: any, b: any): number
	if a == b then
		return 0
	end
	if a == nil then
		return -1
	end
	if b == nil then
		return 1
	end
	return if a < b then -1 else 1
end

function CommandOrder.less(a: SimTypes.InputCommand, b: SimTypes.InputCommand): boolean
	for _, field in { "playerId", "kind", "weapon", "targetId", "deviceClass", "charge" } do
		local order = compare((a :: any)[field], (b :: any)[field])
		if order ~= 0 then
			return order < 0
		end
	end
	for _, field in { "aimOrigin", "aimDir" } do
		local av: vector? = (a :: any)[field]
		local bv: vector? = (b :: any)[field]
		if av == bv then
			continue
		end
		if av == nil or bv == nil then
			return av == nil
		end
		for _, axis in { "x", "y", "z" } do
			local order = compare((av :: any)[axis], (bv :: any)[axis])
			if order ~= 0 then
				return order < 0
			end
		end
	end
	local features: { [string]: boolean } = {}
	for key in a.assist or {} do
		features[key] = true
	end
	for key in b.assist or {} do
		features[key] = true
	end
	for _, key in SimUtil.sortedKeys(features) do
		local order = compare(if a.assist then a.assist[key] else nil, if b.assist then b.assist[key] else nil)
		if order ~= 0 then
			return order < 0
		end
	end
	return false
end

return CommandOrder
