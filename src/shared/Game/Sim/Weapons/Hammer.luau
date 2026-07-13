--!strict

local Sim = script.Parent.Parent
local SimTypes = require(Sim.SimTypes)
local SimUtil = require(Sim.SimUtil)
local WeaponKit = require(Sim.WeaponKit)
local Combat = require(Sim.Parent.Parent.Parent.Config.Combat)

type Vec = SimTypes.Vec
type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type InputCommand = SimTypes.InputCommand
type SimEvent = SimTypes.SimEvent

type KitState = {
	cooldown: number,
	activeRemaining: number,
	recoveryRemaining: number,
	direction: Vec?,
	hitTargetId: string?,
}

local Hammer = {}
Hammer.kind = "Hammer"
Hammer.commands = { Throw = true } :: { [SimTypes.CommandKind]: boolean }

local function config()
	return Combat.Hammer
end

local function pushEvent(events: { SimEvent }, state: SimState, event: SimEvent)
	event.tick = state.tick
	table.insert(events, event)
end

local function hasHeldBall(state: SimState, playerId: string): boolean
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

local function horizontal(direction: Vec): Vec?
	local flat = vector.create(direction.x, 0, direction.z)
	local magnitude = vector.magnitude(flat)
	if magnitude <= 1e-4 then
		return nil
	end
	return flat / magnitude
end

local function hasLineOfSight(world: WorldSnapshot, from: Vec, target: SimTypes.CharacterSnapshot): boolean
	local toTarget = target.position - from
	local distance = vector.magnitude(toTarget)
	if distance <= 1e-6 then
		return true
	end
	local hit = world.collision.sweepSphere(from, toTarget, config().LineOfSightRadius)
	return hit == nil or hit.distance >= distance - target.radius
end

local function findHitTarget(playerId: string, origin: Vec, direction: Vec, world: WorldSnapshot): string?
	local cfg = config()
	local bestId: string? = nil
	local bestForward = math.huge

	for _, targetId in SimUtil.sortedKeys(world.characters) do
		if targetId == playerId then
			continue
		end
		local target = world.characters[targetId]
		if not target.alive or target.invulnerable then
			continue
		end

		local offset = target.position - origin
		local forward = vector.dot(offset, direction)
		if forward < 0 or forward > cfg.Range + target.radius then
			continue
		end

		local flatOffset = vector.create(offset.x, 0, offset.z)
		local lateral = vector.magnitude(flatOffset - direction * forward)
		if lateral > cfg.Width * 0.5 + target.radius then
			continue
		end
		if math.abs(offset.y) > cfg.Height * 0.5 then
			continue
		end
		if not hasLineOfSight(world, origin, target) then
			continue
		end
		if forward < bestForward then
			bestForward = forward
			bestId = targetId
		end
	end

	return bestId
end

function Hammer.init(): KitState
	return {
		cooldown = 0,
		activeRemaining = 0,
		recoveryRemaining = 0,
		direction = nil,
		hitTargetId = nil,
	}
end

function Hammer.handleInput(
	kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	if command.kind ~= "Throw" then
		return false
	end
	if kitState.cooldown > 0 or kitState.activeRemaining > 0 or kitState.recoveryRemaining > 0 then
		return true
	end
	if hasHeldBall(state, command.playerId) then
		return false
	end

	local character = world.characters[command.playerId]
	local aimDir = command.aimDir
	if character == nil or not character.alive or aimDir == nil then
		return false
	end

	local direction = horizontal(aimDir)
	if direction == nil then
		return false
	end

	local cfg = config()
	kitState.cooldown = cfg.Cooldown
	kitState.activeRemaining = cfg.ActiveDuration
	kitState.recoveryRemaining = 0
	kitState.direction = direction
	kitState.hitTargetId = nil

	pushEvent(events, state, {
		kind = "HammerSwing",
		tick = 0,
		projectileId = nil,
		playerId = command.playerId,
		sourceId = command.playerId,
		targetId = nil,
		position = character.position,
		normal = nil,
		direction = direction,
	})

	return true
end

local function resolveHit(
	kitState: KitState,
	playerId: string,
	state: SimState,
	world: WorldSnapshot,
	events: { SimEvent }
)
	local direction = kitState.direction
	local character = world.characters[playerId]
	if direction == nil or character == nil or not character.alive then
		return
	end

	local targetId = findHitTarget(playerId, character.position, direction, world)
	if targetId == nil then
		return
	end

	kitState.hitTargetId = targetId
	kitState.activeRemaining = 0
	kitState.recoveryRemaining = config().HitRecovery

	pushEvent(events, state, {
		kind = "HammerHit",
		tick = 0,
		projectileId = nil,
		playerId = playerId,
		sourceId = playerId,
		targetId = targetId,
		position = world.characters[targetId].position,
		normal = nil,
		direction = direction,
	})
	pushEvent(events, state, {
		kind = "Elim",
		tick = 0,
		projectileId = nil,
		playerId = playerId,
		sourceId = playerId,
		targetId = targetId,
		position = world.characters[targetId].position,
		normal = nil,
		direction = direction,
	})
end

function Hammer.tickPlayer(
	kitState: KitState,
	playerId: string,
	state: SimState,
	world: WorldSnapshot,
	dt: number,
	events: { SimEvent }
)
	kitState.cooldown = math.max(kitState.cooldown - dt, 0)
	kitState.recoveryRemaining = math.max(kitState.recoveryRemaining - dt, 0)

	if kitState.activeRemaining <= 0 then
		return
	end

	resolveHit(kitState, playerId, state, world, events)
	if kitState.hitTargetId ~= nil then
		return
	end

	kitState.activeRemaining = math.max(kitState.activeRemaining - dt, 0)
	if kitState.activeRemaining <= 0 then
		kitState.recoveryRemaining = config().MissRecovery
		pushEvent(events, state, {
			kind = "HammerMiss",
			tick = 0,
			projectileId = nil,
			playerId = playerId,
			sourceId = playerId,
			targetId = nil,
			position = world.characters[playerId] and world.characters[playerId].position or nil,
			normal = nil,
			direction = kitState.direction,
		})
	end
end

return (Hammer :: any) :: WeaponKit.WeaponKit
