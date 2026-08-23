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
			state.players[playerId] = {
				id = playerId,
				weapons = weapons,
				equipped = WeaponRegistry.defaultKind(),
				heldBallLastTick = false,
			}
		end
	end
	for _, playerId in SimUtil.sortedKeys(state.players) do
		if world.characters[playerId] == nil then
			state.players[playerId] = nil
		end
	end
end

-- Which kits may answer this command for this player.
--
-- A command only one weapon claims routes to it whatever is equipped. That is
-- what keeps Catch available while the hammer is out -- requiring the dodgeball
-- to be equipped before a ball could be caught would make the ball unobtainable
-- for anyone holding the hammer, and there would be no way out of that.
--
-- When more than one weapon claims a command, the equipped one decides. This is
-- the whole of the routing rule; there is no per-weapon special case.
local function kitsFor(state: SimState, playerId: string, kind: string)
	local claiming = WeaponRegistry.forCommand(kind)
	if #claiming <= 1 then
		return claiming
	end
	local equipped = state.players[playerId].equipped
	for _, kit in claiming do
		if kit.kind == equipped then
			return { kit }
		end
	end
	return claiming
end

-- Gaining a ball equips whichever weapon uses one. Runs before equip commands so
-- a player who deliberately switches away on the same tick keeps their choice,
-- and before the action loop so a ball granted this tick can be thrown on it.
local function autoEquipOnPickup(state: SimState)
	local handBallKind = WeaponRegistry.handBallKind()
	if handBallKind == nil then
		return
	end
	for _, playerId in SimUtil.sortedKeys(state.players) do
		local player = state.players[playerId]
		local holding = SimUtil.hasHandBall(state, playerId)
		if holding and not player.heldBallLastTick then
			player.equipped = handBallKind
		end
		player.heldBallLastTick = holding
	end
end

-- Equip is a preference, not an action: it is applied in its own pass so it
-- never consumes the one action a player gets per tick, and so an equip and a
-- throw sent together resolve as "switch, then throw with the new weapon".
local function applyEquips(state: SimState, commands: { InputCommand })
	for _, command in commands do
		if command.kind ~= "Equip" then
			continue
		end
		local player = state.players[command.playerId]
		local weapon = command.weapon
		if player == nil or weapon == nil or not WeaponRegistry.isKind(weapon) then
			continue
		end
		player.equipped = weapon
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
	autoEquipOnPickup(state)
	applyEquips(state, commands)

	local handledPlayers: { [string]: boolean } = {}
	for _, command in commands do
		if command.kind == "Equip" then
			continue
		end
		local player = state.players[command.playerId]
		if player and not handledPlayers[command.playerId] then
			for _, kit in kitsFor(state, command.playerId, command.kind) do
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
