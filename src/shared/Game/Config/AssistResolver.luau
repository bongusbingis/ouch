-- Name: AssistResolver.luau
-- Author: Jack C.
-- Description: Aim-assist device scaling on top of the generic PlayerConfigResolver: turns a resolved 0-1 strength into a per-device strength (a zero device scale reads as off), and re-exports the generic resolve/coerce/bucket so aim consumers keep one import.
-- Created: 2026-08-19

--!strict

local PlayerConfigResolver = require(script.Parent.PlayerConfigResolver)

local AssistResolver = {}

export type Entry = PlayerConfigResolver.Entry

AssistResolver.coerce = PlayerConfigResolver.coerce
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
