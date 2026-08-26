-- Name: SimUtil.luau
-- Author: Jack C.
-- Description: Predicates and helpers shared across every weapon and projectile module, including deterministic key ordering, team and line-of-sight checks, and event emission.
-- Created: 2026-07-12

--!strict

local SimTypes = require(script.Parent.SimTypes)

type Vec = SimTypes.Vec
type SimState = SimTypes.SimState
type SimEvent = SimTypes.SimEvent
type WorldSnapshot = SimTypes.WorldSnapshot

local SimUtil = {}

function SimUtil.sortedKeys<K, V>(map: { [K]: V }): { K }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function SimUtil.pushEvent(events: { SimEvent }, state: SimState, event: SimEvent)
	event.tick = state.tick
	table.insert(events, event)
end

function SimUtil.hasHandBall(state: SimState, playerId: string): boolean
	for _, id in SimUtil.sortedKeys(state.projectiles) do
		local projectile = state.projectiles[id]
		if
			(projectile.phase == "Held" or projectile.phase == "Windup")
			and (projectile.heldBy == playerId or projectile.ownerId == playerId)
		then
			return true
		end
	end
	return false
end

function SimUtil.sameTeam(world: WorldSnapshot, a: string?, b: string?): boolean
	if a == nil or b == nil then
		return false
	end
	local ca = world.characters[a]
	local cb = world.characters[b]
	return ca ~= nil and cb ~= nil and ca.teamId ~= nil and ca.teamId == cb.teamId
end

function SimUtil.hasLineOfSight(
	world: WorldSnapshot,
	from: Vec,
	target: SimTypes.CharacterSnapshot,
	radius: number
): boolean
	local toTarget = target.position - from
	local distance = vector.magnitude(toTarget)
	if distance <= 1e-6 then
		return true
	end
	local hit = world.collision.sweepSphere(from, toTarget, radius)
	return hit == nil or hit.distance >= distance - target.radius
end

function SimUtil.assistStrength(command: SimTypes.InputCommand, feature: string): number
	local assist = command.assist
	if assist == nil then
		return 0
	end
	return math.clamp(assist[feature] or 0, 0, 1)
end

return SimUtil
