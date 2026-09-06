-- Name: WriteThroughProxy.luau
-- Author: Jack C.
-- Description: Wraps a profile table so nested reads stay writable and every assignment is forwarded to the replication writer, keeping one copy of the data.
-- Created: 2026-08-23

--!strict

local WriteThroughProxy = {}

export type Writer = {
	Set: (self: Writer, path: { any }, value: any) -> (),
}

local function wrap(data: { [any]: any }, writer: Writer, path: { any }?): { [any]: any }
	local proxy = {}
	setmetatable(proxy, {
		__index = function(_, key)
			local value = data[key]
			if type(value) == "table" then
				local nestedPath = table.clone(path or {})
				table.insert(nestedPath, key)
				return wrap(value, writer, nestedPath)
			end
			return value
		end,
		__newindex = function(_, key, value)
			local fullPath = table.clone(path or {})
			table.insert(fullPath, key)
			data[key] = value
			writer:Set(fullPath, value)
		end,
		__len = function()
			return #data
		end,
		__pairs = function()
			return pairs(data)
		end,
		__ipairs = function()
			return ipairs(data)
		end,
		__iter = function()
			return next, data, nil
		end,
	})
	return proxy
end

function WriteThroughProxy.wrap(data: { [any]: any }, writer: Writer): { [any]: any }
	return wrap(data, writer, nil)
end

function WriteThroughProxy.snapshot(data: { [any]: any }): { [any]: any }
	local result = {}
	for key, value in data do
		result[key] = if type(value) == "table" then WriteThroughProxy.snapshot(value) else value
	end
	return result
end

return WriteThroughProxy
