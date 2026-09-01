-- Name: PlayerConfigResolver.luau
-- Author: Jack C.
-- Description: Generic per-player AB config resolution: raw experience-config values in, validated and defaulted values out, plus the Default/Variant cohort label used for analytics. Schema-agnostic, so any per-player experiment resolves through it, not just aim assist.
-- Created: 2026-09-01

--!strict

local PlayerConfigResolver = {}

export type Entry = {
	Key: string,
	Type: "number" | "boolean",
	Default: any,
	Minimum: number?,
	Maximum: number?,
}

function PlayerConfigResolver.coerce(entry: Entry, raw: any): any
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

function PlayerConfigResolver.resolve(entries: { Entry }, rawValues: { [string]: any }): { [string]: any }
	local resolved = {}
	for _, entry in entries do
		resolved[entry.Key] = PlayerConfigResolver.coerce(entry, rawValues[entry.Key])
	end
	return resolved
end

-- Default when every resolved leaf still equals its baked default, Variant once
-- any leaf differs. A rejected override never changes a leaf, so it stays
-- Default: the cohort names what the player actually experiences.
function PlayerConfigResolver.bucket(entries: { Entry }, resolved: { [string]: any }): string
	for _, entry in entries do
		if resolved[entry.Key] ~= entry.Default then
			return "Variant"
		end
	end
	return "Default"
end

return table.freeze(PlayerConfigResolver)
