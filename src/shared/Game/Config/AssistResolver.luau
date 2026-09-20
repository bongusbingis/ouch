-- Description: Aim-assist device scaling and shared per-player candidate validation.

--!strict

local PlayerConfigResolver = require(script.Parent.PlayerConfigResolver)

local AssistResolver = {}

export type Entry = PlayerConfigResolver.Entry

AssistResolver.resolve = PlayerConfigResolver.resolve
AssistResolver.bucket = PlayerConfigResolver.bucket

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

return table.freeze(AssistResolver)
