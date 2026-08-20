--!strict

-- Pure resolution of a player's assist scalars: raw config values in, validated
-- and device-scaled numbers out. Kept separate from the service so the rules
-- that decide whether an assist is active, and how strongly, are testable
-- without a config service, a player, or a DataModel.

local AssistResolver = {}

export type Entry = {
	Key: string,
	Type: "number" | "boolean",
	Default: any,
	Minimum: number?,
	Maximum: number?,
}

-- Validates one raw value against its declared entry, falling back to the
-- default rather than letting a bad config reach gameplay.
function AssistResolver.coerce(entry: Entry, raw: any): any
	if typeof(raw) ~= entry.Type then
		return entry.Default
	end
	if entry.Type == "number" then
		local value = raw :: number
		if value ~= value or value == math.huge or value == -math.huge then
			return entry.Default
		end
		if entry.Minimum and value < entry.Minimum then
			return entry.Default
		end
		if entry.Maximum and value > entry.Maximum then
			return entry.Default
		end
	end
	return raw
end

function AssistResolver.resolve(entries: { Entry }, rawValues: { [string]: any }): { [string]: any }
	local resolved = {}
	for _, entry in entries do
		resolved[entry.Key] = AssistResolver.coerce(entry, rawValues[entry.Key])
	end
	return resolved
end

-- Effective 0-1 strength for one feature. Disabled, a zero strength, and a zero
-- device scale all collapse to the same answer, so a rollback by any of the
-- three routes behaves identically.
function AssistResolver.strength(
	resolved: { [string]: any },
	deviceScale: { [string]: number },
	feature: string
): number
	if resolved[feature .. "Enabled"] ~= true then
		return 0
	end
	local value = resolved[feature .. "Strength"]
	if typeof(value) ~= "number" then
		return 0
	end
	local scale = deviceScale[feature]
	if typeof(scale) ~= "number" then
		return 0
	end
	return math.clamp(value, 0, 1) * math.clamp(scale, 0, 1)
end

function AssistResolver.scaleFor(deviceScales: { [string]: { [string]: number } }, deviceClass: string?)
	return deviceScales[deviceClass or "Mouse"] or deviceScales.Mouse
end

-- Which A/B cohort a player's resolved assists put them in. Deliberately coarse:
-- analytics dimensions want low cardinality, and the question a config
-- experiment actually asks is "did anything change for this player", not "by
-- exactly how much". A richer label would need the config layer to expose a
-- variant id, which it does not.
function AssistResolver.bucket(entries: { Entry }, resolved: { [string]: any }): string
	for _, entry in entries do
		if resolved[entry.Key] ~= entry.Default then
			return "Variant"
		end
	end
	return "Default"
end

return table.freeze(AssistResolver)
