-- Description: Validates whole per-player config candidates. Absent keys use declared defaults; malformed present keys reject the candidate.

--!strict

local PlayerConfigResolver = {}

export type Entry = {
	Key: string,
	Type: "number" | "boolean",
	Default: any,
	Minimum: number?,
	Maximum: number?,
}

local function expected(entry: Entry): string
	if entry.Type == "boolean" then
		return "boolean"
	end
	if entry.Minimum ~= nil and entry.Maximum ~= nil then
		return `finite number from {entry.Minimum} to {entry.Maximum}`
	end
	if entry.Minimum ~= nil then
		return `finite number >= {entry.Minimum}`
	end
	if entry.Maximum ~= nil then
		return `finite number <= {entry.Maximum}`
	end
	return "finite number"
end

local function received(raw: any): string
	if typeof(raw) == "string" then
		return `string {string.format("%q", raw)}`
	end
	return `{typeof(raw)} {tostring(raw)}`
end

function PlayerConfigResolver.resolve(
	entries: { Entry },
	rawValues: { [string]: any }
): (boolean, string?, { [string]: any }?)
	local resolved: { [string]: any } = {}
	for _, entry in entries do
		local raw = rawValues[entry.Key]
		if raw == nil then
			resolved[entry.Key] = entry.Default
		else
			local valid = typeof(raw) == entry.Type
			if valid and entry.Type == "number" then
				local value = raw :: number
				valid = value == value
					and value ~= math.huge
					and value ~= -math.huge
					and (entry.Minimum == nil or value >= entry.Minimum)
					and (entry.Maximum == nil or value <= entry.Maximum)
			end
			if not valid then
				return false, `{entry.Key}: expected {expected(entry)}; received {received(raw)}`, nil
			end
			resolved[entry.Key] = raw
		end
	end
	return true, nil, resolved
end

-- Default when every resolved leaf still equals its baked default, Variant once
-- any leaf differs. Call only with a successfully resolved candidate.
function PlayerConfigResolver.bucket(entries: { Entry }, resolved: { [string]: any }): string
	for _, entry in entries do
		if resolved[entry.Key] ~= entry.Default then
			return "Variant"
		end
	end
	return "Default"
end

return table.freeze(PlayerConfigResolver)
