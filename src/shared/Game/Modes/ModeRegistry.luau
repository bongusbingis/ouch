--!strict

local GameMode = require(script.Parent.GameMode)
local FFA = require(script.Parent.FFA)
--local Scramble = require(script.Parent.Scramble)

local modes: { GameMode.GameMode } = {
	FFA,
	--Scramble,
}

local DEFAULT_ID = "FFA"

local ModeRegistry = {}

function ModeRegistry.all(): { GameMode.GameMode }
	return modes
end

function ModeRegistry.get(id: string): GameMode.GameMode?
	for _, mode in modes do
		if mode.id == id then
			return mode
		end
	end
	return nil
end

function ModeRegistry.default(): GameMode.GameMode
	local mode = ModeRegistry.get(DEFAULT_ID)
	return assert(mode, `[ModeRegistry] default mode "{DEFAULT_ID}" is not registered`)
end

return ModeRegistry
