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

local function target(key: string): (any?, { string }?, string?)
	local moduleName, path = ConfigOverrides.parseKey(key)
	if moduleName == nil or path == nil then
		return nil, nil, `malformed key "{key}"`
	end
	local moduleTable = modules[moduleName]
	if moduleTable == nil then
		return nil, nil, `missing module "{moduleName}" for "{key}"`
	end
	local valid, reason = ConfigOverrides.checkPath(moduleTable, path)
	if not valid then
		return nil, nil, `"{key}": {reason}`
	end
	return moduleTable, path, nil
end

function ConfigRuntime.apply(accepted: { [string]: any }): (boolean, string?, { [string]: any }?)
	local changed = {}
	local writes = {}

	for key in applied do
		if accepted[key] == nil then
			local baked = defaults[key]
			if baked == nil then
				return false, `missing baked value for "{key}"`, nil
			end
			writes[key] = baked
		end
	end

	for key, value in accepted do
		if applied[key] ~= value then
			writes[key] = value
		end
	end

	-- Config modules are plain dictionaries. Preflight every changed target before
	-- writing any leaf, including leaves being restored to their baked value.
	for key in writes do
		local _, _, reason = target(key)
		if reason ~= nil then
			return false, reason, nil
		end
	end

	for key, value in writes do
		local moduleTable, path = target(key)
		local resolvedPath = path :: { string }
		if defaults[key] == nil then
			defaults[key] = ConfigOverrides.readPath(moduleTable, resolvedPath)
		end
		assert(
			ConfigOverrides.writePath(moduleTable, resolvedPath, value),
			`[ConfigRuntime] preflighted target changed: "{key}"`
		)
		changed[key] = value
	end
	applied = table.clone(accepted)

	if next(changed) ~= nil then
		for _, listener in listeners do
			local ok, err = pcall(listener, changed)
			if not ok then
				warn(`[ConfigRuntime] listener error: {err}`)
			end
		end
	end
	return true, nil, changed
end

function ConfigRuntime.activeOverrides(): { [string]: any }
	return table.clone(applied)
end

function ConfigRuntime.clear()
	local ok, reason = ConfigRuntime.apply({})
	assert(ok, `[ConfigRuntime] clear failed: {reason}`)
	modules = {}
	defaults = {}
	applied = {}
	listeners = {}
end

return table.freeze(ConfigRuntime)
