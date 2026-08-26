-- Name: AssistResolver.luau
-- Author: Jack C.
-- Description: Pure resolution of a player's aim-assist scalars: raw config values in, validated and device-scaled numbers out, plus the cohort label used for analytics.
-- Created: 2026-08-19

--!strict

local AssistResolver = {}

export type Entry = {
	Key: string,
	Type: "number" | "boolean",
	Default: any,
	Minimum: number?,
	Maximum: number?,
}

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

function AssistResolver.bucket(entries: { Entry }, resolved: { [string]: any }): string
	for _, entry in entries do
		if resolved[entry.Key] ~= entry.Default then
			return "Variant"
		end
	end
	return "Default"
end

return table.freeze(AssistResolver)
