--!strict

local SimTypes = require(script.Parent.SimTypes)
local SimUtil = require(script.Parent.SimUtil)
local WeaponRegistry = require(script.Parent.WeaponRegistry)
local Projectiles = require(script.Parent.Projectiles)

type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type InputCommand = SimTypes.InputCommand
type SimEvent = SimTypes.SimEvent

-- The single deterministic combat step, run by the authoritative server.
-- Owns no engine state: characters and geometry arrive
-- via the snapshot, time is the tick counter.

local SimCore = {}

SimCore.newState = SimTypes.newState

local function syncPlayers(state: SimState, world: WorldSnapshot)
	for _, playerId in SimUtil.sortedKeys(world.characters) do
		if state.players[playerId] == nil then
			local weapons = {}
			for _, kit in WeaponRegistry.all() do
				weapons[kit.kind] = kit.init()
			end
			state.players[playerId] = { id = playerId, weapons = weapons }
		end
	end
	for _, playerId in SimUtil.sortedKeys(state.players) do
		if world.characters[playerId] == nil then
			state.players[playerId] = nil
		end
	end
end

-- Canonical command order: the server may receive different arrival orders
-- than they were sent in; sorting keeps a tick reproducible.
local function sortCommands(commands: { InputCommand })
	table.sort(commands, function(a, b)
		if a.playerId ~= b.playerId then
			return a.playerId < b.playerId
		end
		return a.kind < b.kind
	end)
end

function SimCore.step(state: SimState, commands: { InputCommand }, world: WorldSnapshot, dt: number): { SimEvent }
	local events: { SimEvent } = {}
	state.tick += 1

	syncPlayers(state, world)
	sortCommands(commands)

	local handledPlayers: { [string]: boolean } = {}
	for _, command in commands do
		local player = state.players[command.playerId]
		if player and not handledPlayers[command.playerId] then
			for _, kit in WeaponRegistry.forCommand(command.kind) do
				if kit.handleInput(player.weapons[kit.kind], state, command, world, events) then
					handledPlayers[command.playerId] = true
					break
				end
			end
		end
	end

	for _, kit in WeaponRegistry.all() do
		for _, playerId in SimUtil.sortedKeys(state.players) do
			kit.tickPlayer(state.players[playerId].weapons[kit.kind], playerId, state, world, dt, events)
		end
		if kit.tickWorld then
			kit.tickWorld(state, world, dt, events)
		end
	end

	Projectiles.step(state, world, dt, events)
	return events
end

return SimCore
