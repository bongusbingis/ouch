--!strict

-- Pure rules for turning raw Roblox experience config values into overrides the
-- game may apply. Every value crossing into gameplay passes through resolve, on
-- the server when it is read from ConfigService and again on the client when it
-- is decoded from replication, so neither a config authoring mistake nor a
-- malformed payload can install a value outside its declared type and range.
--
-- Keys not present in the registry are ignored rather than applied.

local ConfigOverrides = {}

export type Entry = {
	Key: string,
	Type: "number" | "boolean" | "string",
	Minimum: number?,
	Maximum: number?,
}

export type Rejection = {
	Key: string,
	Reason: string,
}

function ConfigOverrides.parseKey(key: string): (string?, { string }?)
	local segments = string.split(key, ".")
	if #segments < 2 then
		return nil, nil
	end
	for _, segment in segments do
		if segment == "" then
			return nil, nil
		end
	end
	local moduleName = table.remove(segments, 1)
	return moduleName, segments
end

function ConfigOverrides.validate(entry: Entry, value: any): (any?, string?)
	if typeof(value) ~= entry.Type then
		return nil, `expected {entry.Type}, got {typeof(value)}`
	end
	if entry.Type == "number" then
		local numeric = value :: number
		if numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
			return nil, "not a finite number"
		end
		if entry.Minimum and numeric < entry.Minimum then
			return nil, `below minimum {entry.Minimum}`
		end
		if entry.Maximum and numeric > entry.Maximum then
			return nil, `above maximum {entry.Maximum}`
		end
	end
	return value, nil
end

function ConfigOverrides.resolve(entries: { Entry }, rawValues: { [string]: any }): ({ [string]: any }, { Rejection })
	local accepted = {}
	local rejected = {}
	for _, entry in entries do
		local raw = rawValues[entry.Key]
		if raw ~= nil then
			local moduleName, path = ConfigOverrides.parseKey(entry.Key)
			if moduleName == nil or path == nil then
				table.insert(rejected, { Key = entry.Key, Reason = "malformed key" })
			else
				local value, reason = ConfigOverrides.validate(entry, raw)
				if value == nil then
					table.insert(rejected, { Key = entry.Key, Reason = reason or "invalid" })
				else
					accepted[entry.Key] = value
				end
			end
		end
	end
	return accepted, rejected
end

-- Splits accepted overrides by whether the deterministic sim reads their module.
function ConfigOverrides.partition(
	accepted: { [string]: any },
	simCritical: { [string]: boolean }
): ({ [string]: any }, { [string]: any })
	local immediate = {}
	local staged = {}
	for key, value in accepted do
		local moduleName = ConfigOverrides.parseKey(key)
		if moduleName ~= nil and simCritical[moduleName] then
			staged[key] = value
		else
			immediate[key] = value
		end
	end
	return immediate, staged
end

-- A key is projected onto an instance name under underscores, keeping dots out of
-- name-based lookups. Neither side reverses this: both walk the registry and
-- derive the name from the key, so no key round trips through its projection.
function ConfigOverrides.projectedName(key: string): string
	return (string.gsub(key, "%.", "_"))
end

function ConfigOverrides.readPath(root: any, path: { string }): any
	local cursor = root
	for _, segment in path do
		if typeof(cursor) ~= "table" then
			return nil
		end
		cursor = cursor[segment]
	end
	return cursor
end

-- Writes only where the leaf already exists, so a key that no longer matches
-- the config module cannot introduce a new field.
function ConfigOverrides.writePath(root: any, path: { string }, value: any): boolean
	local cursor = root
	for index = 1, #path - 1 do
		if typeof(cursor) ~= "table" then
			return false
		end
		cursor = cursor[path[index]]
	end
	local leaf = path[#path]
	if typeof(cursor) ~= "table" or cursor[leaf] == nil or table.isfrozen(cursor) then
		return false
	end
	cursor[leaf] = value
	return true
end

return table.freeze(ConfigOverrides)
