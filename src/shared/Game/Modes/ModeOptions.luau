--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes"))
local ModeRegistry = require(script.Parent.ModeRegistry)

local ModeOptions = {}

local function available(modeId: string): boolean
	local definition = GameModes.Modes[modeId]
	return definition ~= nil and definition.Enabled and ModeRegistry.get(modeId) ~= nil
end

local function collect(options: { string }): { string }
	local result = {}
	local seen = {}
	for _, modeId in options do
		if not seen[modeId] and available(modeId) then
			seen[modeId] = true
			table.insert(result, modeId)
		end
	end
	return result
end

function ModeOptions.resolve(options: { string }): { string }
	local resolved = collect(options)
	return if #resolved > 0 then resolved else collect(GameModes.VoteOptions)
end

function ModeOptions.equals(first: { string }, second: { string }): boolean
	if #first ~= #second then
		return false
	end
	for index, modeId in first do
		if second[index] ~= modeId then
			return false
		end
	end
	return true
end

return table.freeze(ModeOptions)
