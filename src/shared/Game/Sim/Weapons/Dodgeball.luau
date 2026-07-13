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
Dodgeball.commands = { Throw = true, Recall = true } :: { [SimTypes.CommandKind]: boolean }

local function config()
	return Combat.Dodgeball
end

local function pushEvent(events: { SimEvent }, state: SimState, event: SimEvent)
	event.tick = state.tick
	table.insert(events, event)
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

local function findRecallableBall(state: SimState, playerId: string): ProjectileState?
	for _, id in SimUtil.sortedKeys(state.projectiles) do
		local projectile = state.projectiles[id]
		if
			projectile.ownerId == playerId
			and (projectile.phase == "InFlight" or projectile.phase == "Bouncing" or projectile.phase == "Free")
		then
			return projectile
		end
	end
	return nil
end

local function hasLineOfSight(world: WorldSnapshot, aimOrigin: Vec, target: SimTypes.CharacterSnapshot): boolean
	local toTarget = target.position - aimOrigin
	local occlusion = world.collision.sweepSphere(aimOrigin, toTarget, 0.2)
	return occlusion == nil or occlusion.distance >= vector.magnitude(toTarget) - target.radius
end

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
		if characterId == command.playerId then
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
		if not hasLineOfSight(world, aimOrigin, character) then
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
	if targetId == nil or targetId == command.playerId then
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

	if not hasLineOfSight(world, aimOrigin, target) then
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
	pushEvent(events, state, {
		kind = "BallWindup",
		tick = 0,
		projectileId = ball.id,
		playerId = command.playerId,
		targetId = ball.releaseTargetId,
	})
	return true
end

local function handleRecall(
	kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	if kitState.recallCooldown > 0 then
		return false
	end
	local character = world.characters[command.playerId]
	if character == nil or not character.alive then
		return false
	end
	local ball = findRecallableBall(state, command.playerId)
	if ball == nil then
		return false
	end

	local cfg = config()
	if vector.magnitude(ball.position - character.position) > cfg.RecallMaxDistance then
		return false
	end

	ball.phase = "Recalling"
	ball.targetId = nil
	kitState.recallCooldown = cfg.RecallCooldown
	pushEvent(events, state, {
		kind = "BallRecallStarted",
		tick = 0,
		projectileId = ball.id,
		playerId = command.playerId,
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
	elseif command.kind == "Recall" then
		return handleRecall(kitState, state, command, world, events)
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
	kitState.recallCooldown = math.max(kitState.recallCooldown - dt, 0)
end

local function tickPickups(state: SimState, world: WorldSnapshot, events: { SimEvent })
	local cfg = config()
	for _, playerId in SimUtil.sortedKeys(world.characters) do
		local character = world.characters[playerId]
		if not character.alive or findHeldBall(state, playerId) ~= nil then
			continue
		end

		local bestBall: ProjectileState? = nil
		local bestDistance = cfg.PickupRadius
		for _, id in SimUtil.sortedKeys(state.projectiles) do
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
			pushEvent(
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
