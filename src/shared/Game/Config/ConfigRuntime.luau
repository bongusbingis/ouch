-- Description: Applies validated overrides onto the live config tables, capturing each leaf's shipped value on first override and restoring it exactly when the override disappears.

--!strict

local ConfigOverrides = require(script.Parent.ConfigOverrides)

local ConfigRuntime = {}

local modules: { [string]: any } = {}
local defaults: { [string]: any } = {}
local applied: { [string]: any } = {}
local listeners: { ({ [string]: any }) -> () } = {}

function ConfigRuntime.register(name: string, moduleTable: any)
	assert(typeof(moduleTable) == "table", `[ConfigRuntime] module "{name}" must be a table`)
	modules[name] = moduleTable
end

function ConfigRuntime.subscribe(listener: ({ [string]: any }) -> ())
	table.insert(listeners, listener)
end

local function write(key: string, value: any): boolean
	local moduleName, path = ConfigOverrides.parseKey(key)
	if moduleName == nil or path == nil then
		return false
	end
	local moduleTable = modules[moduleName]
	if moduleTable == nil then
		return false
	end
	if defaults[key] == nil then
		local baked = ConfigOverrides.readPath(moduleTable, path)
		if baked == nil then
			return false
		end
		defaults[key] = baked
	end
	return ConfigOverrides.writePath(moduleTable, path, value)
end

function ConfigRuntime.apply(accepted: { [string]: any }): { [string]: any }
	local changed = {}

	for key in applied do
		if accepted[key] == nil then
			local baked = defaults[key]
			if baked ~= nil and write(key, baked) then
				changed[key] = baked
			end
			applied[key] = nil
		end
	end

	for key, value in accepted do
		if applied[key] ~= value and write(key, value) then
			applied[key] = value
			changed[key] = value
		end
	end

	if next(changed) ~= nil then
		for _, listener in listeners do
			local ok, err = pcall(listener, changed)
			if not ok then
				warn(`[ConfigRuntime] listener error: {err}`)
			end
		end
	end
	return changed
end

function ConfigRuntime.activeOverrides(): { [string]: any }
	return table.clone(applied)
end

function ConfigRuntime.clear()
	ConfigRuntime.apply({})
	modules = {}
	defaults = {}
	applied = {}
	listeners = {}
end

return table.freeze(ConfigRuntime)
