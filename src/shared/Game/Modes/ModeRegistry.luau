-- Description: Lists every registered game mode and resolves them by id, the single place a new mode is registered.

--!strict

local GameMode = require(script.Parent.GameMode)
local FFA = require(script.Parent.FFA)
local Infection = require(script.Parent.Infection)
local TDM = require(script.Parent.TDM)

local modes: { GameMode.GameMode } = {
	FFA,
	TDM,
	Infection,
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
