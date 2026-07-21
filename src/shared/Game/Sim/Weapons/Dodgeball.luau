--!strict

local Sim = script.Parent.Parent
local SimTypes = require(Sim.SimTypes)
local SimUtil = require(Sim.SimUtil)
local WeaponKit = require(Sim.WeaponKit)
local Combat = require(Sim.Parent.Parent.Parent.Config.Combat)
local AimAssist = require(Sim.Parent.Parent.Parent.Config.AimAssist)

type Vec = SimTypes.Vec
type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type InputCommand = SimTypes.InputCommand
type ProjectileState = SimTypes.ProjectileState
type SimEvent = SimTypes.SimEvent

type KitState = {
	throwCooldown: number,
	recallCooldown: number,
}

-- Ball possession has exactly one source of truth: ProjectileState
-- (phase == "Held" and heldBy). Kit state holds only cooldowns.

local Dodgeball = {}
Dodgeball.kind = "Dodgeball"
Dodgeball.commands = { Throw = true } :: { [SimTypes.CommandKind]: boolean }

local function config()
	return Combat.Dodgeball
end

local function deviceRow(deviceClass: string?): AimAssist.DeviceRow
	return AimAssist[deviceClass or "Mouse"] or AimAssist.Mouse
end

local function findHeldBall(state: SimState, playerId: string): ProjectileState?
	for _, id in SimUtil.sortedKeys(state.projectiles) do
		local projectile = state.projectiles[id]
		if projectile.phase == "Held" and projectile.heldBy == playerId then
			return projectile
		end
	end
	return nil
end

local AIM_LINE_OF_SIGHT_RADIUS = 0.2

-- Deterministic in-sim soft-lock: best candidate in the device's selection
-- cone with line of sight, scored by angular offset with a small distance
-- tiebreak. Runs identically on client prediction and server, so there is no
-- client proposal to trust.
local function selectTarget(command: InputCommand, world: WorldSnapshot, aimOrigin: Vec, aimDir: Vec): string?
	local cfg = config()
	local cosCone = math.cos(math.rad(deviceRow(command.deviceClass).SelectionConeDeg))
	local best: string? = nil
	local bestScore = math.huge

	for _, characterId in SimUtil.sortedKeys(world.characters) do
		if characterId == command.playerId or SimUtil.sameTeam(world, command.playerId, characterId) then
			continue
		end
		local character = world.characters[characterId]
		if not character.alive or character.invulnerable then
			continue
		end
		local toTarget = character.position - aimOrigin
		local distance = vector.magnitude(toTarget)
		if distance <= 1e-6 or distance > cfg.TargetSelectRange then
			continue
		end
		local dot = vector.dot(aimDir, toTarget / distance)
		if dot < cosCone then
			continue
		end
		if not SimUtil.hasLineOfSight(world, aimOrigin, character, AIM_LINE_OF_SIGHT_RADIUS) then
			continue
		end
		local score = math.acos(math.clamp(dot, -1, 1)) + distance * 1e-3
		if score < bestScore then
			best = characterId
			bestScore = score
		end
	end
	return best
end

-- Re-check of an explicitly proposed target (traditional-backend path): alive,
-- not self, inside the widened validation cone, unobstructed. Fails open to an
-- unguided throw rather than rejecting the input.
local function validateTarget(command: InputCommand, world: WorldSnapshot, aimOrigin: Vec, aimDir: Vec): string?
	local targetId = command.targetId
	if targetId == nil or targetId == command.playerId or SimUtil.sameTeam(world, command.playerId, targetId) then
		return nil
	end
	local target = world.characters[targetId]
	if target == nil or not target.alive or target.invulnerable then
		return nil
	end

	local toTarget = target.position - aimOrigin
	local distance = vector.magnitude(toTarget)
	if distance <= 1e-6 then
		return nil
	end
	local cosCone = math.cos(math.rad(deviceRow(command.deviceClass).ValidationConeDeg))
	if vector.dot(aimDir, toTarget / distance) < cosCone then
		return nil
	end

	if not SimUtil.hasLineOfSight(world, aimOrigin, target, AIM_LINE_OF_SIGHT_RADIUS) then
		return nil
	end
	return targetId
end

local function handleThrow(
	kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	if kitState.throwCooldown > 0 then
		return false
	end
	local character = world.characters[command.playerId]
	if character == nil or not character.alive then
		return false
	end
	local ball = findHeldBall(state, command.playerId)
	if ball == nil then
		return false
	end

	local cfg = config()
	local aimOrigin = command.aimOrigin
	local aimDir = command.aimDir
	if aimOrigin == nil or aimDir == nil then
		return false
	end
	if vector.magnitude(aimOrigin - character.position) > cfg.ThrowOriginMaxOffset then
		return false
	end
	if vector.magnitude(aimDir) <= 1e-6 then
		return false
	end
	aimDir = vector.normalize(aimDir)

	ball.phase = "Windup"
	ball.ownerId = command.playerId
	ball.position = character.handPosition
	ball.velocity = vector.zero
	ball.releaseAim = aimDir
	ball.releaseTargetId = if command.targetId ~= nil
		then validateTarget(command, world, aimOrigin, aimDir)
		else selectTarget(command, world, aimOrigin, aimDir)
	ball.releaseDeviceClass = command.deviceClass or "Mouse"
	ball.windupRemaining = cfg.WindupDuration
	ball.bounceCount = 0
	ball.flightTime = 0

	kitState.throwCooldown = cfg.ThrowCooldown
	SimUtil.pushEvent(events, state, {
		kind = "BallWindup",
		tick = 0,
		projectileId = ball.id,
		playerId = command.playerId,
		targetId = ball.releaseTargetId,
	})
	return true
end

local function findCatchableBall(
	state: SimState,
	world: WorldSnapshot,
	playerId: string,
	character: SimTypes.CharacterSnapshot
): ProjectileState?
	local bestBall: ProjectileState? = nil
	local bestDistance = config().CatchDistance

	for _, id in SimUtil.sortedKeys(state.projectiles) do
		local projectile = state.projectiles[id]
		if
			projectile.phase ~= "InFlight"
			or projectile.ownerId == nil
			or projectile.ownerId == playerId
			or SimUtil.sameTeam(world, playerId, projectile.ownerId)
		then
			continue
		end

		local offset = character.position - projectile.position
		local distance = vector.magnitude(offset)
		if distance > bestDistance then
			continue
		end
		if vector.magnitude(projectile.velocity) <= 1e-6 or vector.dot(projectile.velocity, offset) <= 0 then
			continue
		end

		bestBall = projectile
		bestDistance = distance
	end

	return bestBall
end

local function handleCatch(
	_kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	local character = world.characters[command.playerId]
	if character == nil or not character.alive or SimUtil.hasHandBall(state, command.playerId) then
		return false
	end

	local ball = findCatchableBall(state, world, command.playerId, character)
	if ball == nil then
		return false
	end

	local previousOwner = ball.ownerId
	ball.phase = "Held"
	ball.heldBy = command.playerId
	ball.ownerId = command.playerId
	ball.position = character.handPosition
	ball.velocity = vector.zero
	ball.targetId = nil
	ball.windupRemaining = 0
	ball.bounceCount = 0
	ball.flightTime = 0
	ball.releaseAim = nil
	ball.releaseTargetId = nil

	SimUtil.pushEvent(events, state, {
		kind = "BallCaught",
		tick = 0,
		projectileId = ball.id,
		playerId = command.playerId,
		sourceId = command.playerId,
		targetId = previousOwner,
		position = ball.position,
	})
	return true
end

function Dodgeball.init(): KitState
	return { throwCooldown = 0, recallCooldown = 0 }
end

function Dodgeball.handleInput(
	kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	if command.kind == "Throw" then
		return handleThrow(kitState, state, command, world, events)
			or handleCatch(kitState, state, command, world, events)
	end
	return false
end

function Dodgeball.tickPlayer(
	kitState: KitState,
	_playerId: string,
	_state: SimState,
	_world: WorldSnapshot,
	dt: number,
	_events: { SimEvent }
)
	kitState.throwCooldown = math.max(kitState.throwCooldown - dt, 0)
end

local function tickPickups(state: SimState, world: WorldSnapshot, events: { SimEvent })
	local cfg = config()
	local projectileIds = SimUtil.sortedKeys(state.projectiles)
	for _, playerId in SimUtil.sortedKeys(world.characters) do
		local character = world.characters[playerId]
		if not character.alive or findHeldBall(state, playerId) ~= nil then
			continue
		end

		local bestBall: ProjectileState? = nil
		local bestDistance = cfg.PickupRadius
		for _, id in projectileIds do
			local projectile = state.projectiles[id]
			if projectile.phase ~= "Free" then
				continue
			end
			local distance = vector.magnitude(projectile.position - character.position)
			if distance <= bestDistance then
				bestBall = projectile
				bestDistance = distance
			end
		end

		if bestBall then
			bestBall.phase = "Held"
			bestBall.heldBy = playerId
			bestBall.ownerId = playerId
			bestBall.position = character.handPosition
			bestBall.windupRemaining = 0
			bestBall.bounceCount = 0
			SimUtil.pushEvent(
				events,
				state,
				{ kind = "BallPickedUp", tick = 0, projectileId = bestBall.id, playerId = playerId }
			)
		end
	end
end

function Dodgeball.tickWorld(state: SimState, world: WorldSnapshot, dt: number, events: { SimEvent })
	local _ = dt
	tickPickups(state, world, events)
end

return (Dodgeball :: any) :: WeaponKit.WeaponKit
