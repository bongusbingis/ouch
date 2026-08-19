--!strict

-- Applies validated overrides onto the live Config module tables. The config
-- tables stay the single source of truth every consumer already reads, so an
-- override is a write into that table rather than a second resolved copy that
-- could drift from it.
--
-- The baked value of each leaf is captured the first time it is overridden and
-- restored exactly when the override later disappears, which is what lets the
-- game fall back to its shipped values without a restart.

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

function ConfigRuntime.onChanged(listener: ({ [string]: any }) -> ())
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

-- Installs exactly the given override set: keys present are written, keys that
-- were applied before and are absent now are restored to their baked value.
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

-- Restores every baked value and forgets registrations. Used by specs and by
-- teardown; gameplay reverts through apply instead.
function ConfigRuntime.clear()
	ConfigRuntime.apply({})
	modules = {}
	defaults = {}
	applied = {}
	listeners = {}
end

return table.freeze(ConfigRuntime)
