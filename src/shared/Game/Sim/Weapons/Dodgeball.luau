-- Name: Dodgeball.luau
-- Author: Jack C.
-- Description: The dodgeball weapon kit: throw gating and cooldowns, soft-lock target selection and validation per device class, charged release, and the catch window, with ball possession read from projectile state rather than duplicated.
-- Created: 2026-07-12

--!strict

local Sim = script.Parent.Parent
local SimTypes = require(Sim.SimTypes)
local SimUtil = require(Sim.SimUtil)
local WeaponKit = require(Sim.WeaponKit)
local Combat = require(Sim.Parent.Parent.Parent.Config.Gameplay.Combat)
local AimAssist = require(Sim.Parent.Parent.Parent.Config.Gameplay.AimAssist)
local MobileInput = require(Sim.Parent.Parent.Parent.Config.Interface.MobileInput)
local Intercept = require(Sim.Intercept)
local TargetSelect = require(Sim.TargetSelect)

type Vec = SimTypes.Vec
type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type InputCommand = SimTypes.InputCommand
type ProjectileState = SimTypes.ProjectileState
type SimEvent = SimTypes.SimEvent

type KitState = {
	throwCooldown: number,
	catchCooldown: number,
	catchRemaining: number,
	catchDirection: Vec?,
	chargeSeconds: number?,
}

local Dodgeball = {}
Dodgeball.kind = "Dodgeball"
Dodgeball.commands =
	{ Throw = true, Catch = true, BeginCharge = true, CancelCharge = true } :: { [SimTypes.CommandKind]: boolean }
Dodgeball.equipOnHandBall = true

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

local function selectTarget(command: InputCommand, world: WorldSnapshot, aimOrigin: Vec, aimDir: Vec): string?
	local targetId = TargetSelect.pick(world, command.playerId, aimOrigin, aimDir, {
		rangeStuds = config().TargetSelectRange,
		coneDeg = deviceRow(command.deviceClass).SelectionConeDeg,
		fadeStartFraction = MobileInput.Assist.ConeFadeStartFraction,
		lineOfSightRadius = AIM_LINE_OF_SIGHT_RADIUS,
	})
	return targetId
end

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
	if command.targetId ~= nil then
		ball.releaseTargetId = validateTarget(command, world, aimOrigin, aimDir)
	elseif SimUtil.assistStrength(command, "ConeSnap") > 0 then
		ball.releaseTargetId = selectTarget(command, world, aimOrigin, aimDir)
	else
		ball.releaseTargetId = nil
	end
	ball.releaseDeviceClass = command.deviceClass or "Mouse"
	ball.releaseCharge = math.min(
		math.clamp(command.charge or 0, 0, 1),
		math.clamp((kitState.chargeSeconds or 0) / cfg.Charge.FullSeconds, 0, 1)
	)
	kitState.chargeSeconds = nil

	local leadStrength = SimUtil.assistStrength(command, "Lead")
	if leadStrength > 0 and ball.releaseTargetId ~= nil then
		local target = world.characters[ball.releaseTargetId]
		if target ~= nil then
			local point = Intercept.solve(aimOrigin, target.position, target.velocity, cfg.ThrowSpeed)
			local confidence = target.velocityConsistency or 0
			ball.releaseAim = Intercept.biasAim(
				aimDir,
				aimOrigin,
				point,
				leadStrength * confidence,
				math.rad(MobileInput.Assist.MaxLeadAngleDeg)
			)
		end
	end
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
	character: SimTypes.CharacterSnapshot,
	catchDirection: Vec,
	lookahead: number
): ProjectileState?
	local cfg = config()
	local bestBall: ProjectileState? = nil
	local bestDistance = cfg.CatchDistance

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

		local toPlayer = character.position - projectile.position
		if not SimUtil.hasLineOfSight(world, projectile.position, character, cfg.Radius) then
			continue
		end
		local speed = vector.magnitude(projectile.velocity)
		if speed <= 1e-6 or vector.dot(projectile.velocity, toPlayer) <= 0 then
			continue
		end

		local toBall = -toPlayer
		local displacement = projectile.velocity * math.max(lookahead, 0)
		local displacementSq = vector.dot(displacement, displacement)
		local alpha = if displacementSq > 1e-9
			then math.clamp(-vector.dot(toBall, displacement) / displacementSq, 0, 1)
			else 0
		local sampledToBall = toBall + displacement * alpha
		local distance = vector.magnitude(sampledToBall)
		if distance > bestDistance then
			continue
		end

		local coneVector = if distance > 1e-6 then sampledToBall else toBall
		if vector.magnitude(coneVector) <= 1e-6 then
			continue
		end
		local coneCos = math.cos(math.rad(cfg.CatchConeDeg * 0.5))
		if vector.dot(catchDirection, vector.normalize(coneVector)) < coneCos then
			continue
		end

		local travel = displacement * alpha
		local travelDistance = vector.magnitude(travel)
		if travelDistance > 1e-6 then
			local hit = world.collision.sweepSphere(projectile.position, travel, cfg.Radius)
			if hit and hit.distance < travelDistance - cfg.ContactSeparation then
				continue
			end
		end

		bestBall = projectile
		bestDistance = distance
	end

	return bestBall
end

local function tryCatch(
	kitState: KitState,
	state: SimState,
	playerId: string,
	world: WorldSnapshot,
	events: { SimEvent },
	lookahead: number
): boolean
	local character = world.characters[playerId]
	local catchDirection = kitState.catchDirection
	if character == nil or not character.alive or catchDirection == nil or SimUtil.hasHandBall(state, playerId) then
		return false
	end

	local ball = findCatchableBall(state, world, playerId, character, catchDirection, lookahead)
	if ball == nil then
		return false
	end

	local previousOwner = ball.ownerId
	ball.phase = "Held"
	ball.heldBy = playerId
	ball.ownerId = playerId
	ball.position = character.handPosition
	ball.velocity = vector.zero
	ball.targetId = nil
	ball.windupRemaining = 0
	ball.bounceCount = 0
	ball.flightTime = 0
	ball.releaseAim = nil
	ball.releaseTargetId = nil
	ball.releaseCharge = nil
	kitState.catchRemaining = 0
	kitState.catchDirection = nil

	SimUtil.pushEvent(events, state, {
		kind = "BallCaught",
		tick = 0,
		projectileId = ball.id,
		playerId = playerId,
		sourceId = playerId,
		targetId = previousOwner,
		position = ball.position,
	})
	return true
end

local function beginCatch(
	kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	if kitState.catchCooldown > 0 or SimUtil.hasHandBall(state, command.playerId) then
		return false
	end
	local character = world.characters[command.playerId]
	local aimDir = command.aimDir
	if character == nil or not character.alive or aimDir == nil or vector.magnitude(aimDir) <= 1e-6 then
		return false
	end

	kitState.catchCooldown = config().CatchCooldown
	kitState.catchRemaining = config().CatchWindow
	kitState.catchDirection = vector.normalize(aimDir)
	SimUtil.pushEvent(events, state, {
		kind = "CatchStarted",
		tick = 0,
		playerId = command.playerId,
		direction = kitState.catchDirection,
	})
	tryCatch(kitState, state, command.playerId, world, events, 0)
	return true
end

function Dodgeball.init(): KitState
	return { throwCooldown = 0, catchCooldown = 0, catchRemaining = 0, catchDirection = nil }
end

function Dodgeball.handleInput(
	kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	if command.kind == "BeginCharge" then
		local character = world.characters[command.playerId]
		if
			character
			and character.alive
			and state.players[command.playerId].equipped == Dodgeball.kind
			and kitState.throwCooldown <= 0
			and findHeldBall(state, command.playerId) ~= nil
			and kitState.chargeSeconds == nil
		then
			kitState.chargeSeconds = 0
		end
		return false
	elseif command.kind == "CancelCharge" then
		kitState.chargeSeconds = nil
		return false
	elseif command.kind == "Throw" then
		return handleThrow(kitState, state, command, world, events)
	elseif command.kind == "Catch" then
		return beginCatch(kitState, state, command, world, events)
	end
	return false
end

function Dodgeball.tickPlayer(
	kitState: KitState,
	playerId: string,
	state: SimState,
	world: WorldSnapshot,
	dt: number,
	events: { SimEvent }
)
	local character = world.characters[playerId]
	if
		character == nil
		or not character.alive
		or state.players[playerId].equipped ~= Dodgeball.kind
		or findHeldBall(state, playerId) == nil
	then
		kitState.chargeSeconds = nil
	elseif kitState.chargeSeconds ~= nil then
		kitState.chargeSeconds = math.min(kitState.chargeSeconds + dt, config().Charge.FullSeconds)
	end
	kitState.throwCooldown = math.max(kitState.throwCooldown - dt, 0)
	kitState.catchCooldown = math.max(kitState.catchCooldown - dt, 0)
	if kitState.catchRemaining <= 0 then
		return
	end
	if tryCatch(kitState, state, playerId, world, events, dt) then
		return
	end
	local previous = kitState.catchRemaining
	kitState.catchRemaining = math.max(previous - dt, 0)
	if previous > 0 and kitState.catchRemaining <= 0 then
		kitState.catchDirection = nil
		SimUtil.pushEvent(events, state, { kind = "CatchMissed", tick = 0, playerId = playerId })
	end
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
