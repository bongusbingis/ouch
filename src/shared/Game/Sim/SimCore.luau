-- Name: SimCore.luau
-- Author: Jack C.
-- Description: The pure fixed-tick simulation step: syncs players, applies weapon equips, canonically sorts commands, routes them to the equipped weapon kit, ticks weapons and projectiles, and returns mutated state plus an ordered event list.
-- Created: 2026-07-12

--!strict

local SimTypes = require(script.Parent.SimTypes)
local SimUtil = require(script.Parent.SimUtil)
local CommandOrder = require(script.Parent.CommandOrder)
local WeaponRegistry = require(script.Parent.WeaponRegistry)
local Projectiles = require(script.Parent.Projectiles)

type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type InputCommand = SimTypes.InputCommand
type SimEvent = SimTypes.SimEvent

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

local function sortCommands(commands: { InputCommand })
	table.sort(commands, CommandOrder.less)
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
