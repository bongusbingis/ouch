-- Name: Projectiles.luau
-- Author: Jack C.
-- Description: The generic swept-projectile subsystem: fixed-tick kinematics, homing, swept collision against characters and static geometry with substepping to prevent tunneling, and the held, windup, flight, bounce, and roll phase machine.
-- Created: 2026-07-12

--!strict

local SimTypes = require(script.Parent.SimTypes)
local SimUtil = require(script.Parent.SimUtil)
local CollisionWorld = require(script.Parent.CollisionWorld)
local ProjectileTrajectory = require(script.Parent.ProjectileTrajectory)
local Combat = require(script.Parent.Parent.Parent.Parent.Config.Combat)
local AimAssist = require(script.Parent.Parent.Parent.Parent.Config.AimAssist)

type Vec = SimTypes.Vec
type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type ProjectileState = SimTypes.ProjectileState
type SimEvent = SimTypes.SimEvent

local Projectiles = {}

local DEFAULT_MAX_CONTACTS_PER_STEP = 4
local DEFAULT_MIN_BOUNCE_NORMAL_SPEED = 1.5
local SETTLE_DROP = 50

local function settle(world: WorldSnapshot, position: Vec, radius: number): Vec
	local drop = vector.create(0, -SETTLE_DROP, 0)
	local hit = world.collision.sweepSphere(position, drop, radius)
	if hit then
		return hit.position
	end
	return position
end

local function clearFlightState(projectile: ProjectileState)
	projectile.velocity = vector.zero
	projectile.targetId = nil
	projectile.flightTime = 0
	projectile.windupRemaining = 0
	projectile.releaseAim = nil
	projectile.releaseTargetId = nil
	projectile.releaseCharge = nil
end

local function becomeFree(projectile: ProjectileState, world: WorldSnapshot, position: Vec)
	local radius = Combat[projectile.archetype].Radius
	projectile.phase = "Free"
	projectile.position = settle(world, position, radius)
	projectile.heldBy = nil
	clearFlightState(projectile)
end

local function comeToRest(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	position: Vec,
	events: { SimEvent }
)
	local rules = world.rules
	local ownerId = projectile.ownerId
	if rules ~= nil and rules.preserveDodgeballs and ownerId ~= nil then
		local owner = world.characters[ownerId]
		if owner ~= nil and owner.alive and not SimUtil.hasHandBall(state, ownerId) then
			projectile.phase = "Held"
			projectile.heldBy = ownerId
			projectile.position = owner.handPosition
			clearFlightState(projectile)
			projectile.bounceCount = 0
			SimUtil.pushEvent(events, state, {
				kind = "BallReturned",
				tick = 0,
				projectileId = projectile.id,
				playerId = ownerId,
				targetId = ownerId,
				position = projectile.position,
			})
			return
		end
	end
	becomeFree(projectile, world, position)
end

local function horizontalOf(v: Vec): Vec
	return vector.create(v.x, 0, v.z)
end

local function beginRolling(projectile: ProjectileState, config: typeof(Combat.Dodgeball), position: Vec)
	local horizontalVelocity = horizontalOf(projectile.velocity)
	projectile.phase = "Rolling"
	projectile.position = position
	projectile.velocity = horizontalVelocity
	projectile.targetId = nil
end

local function chestPosition(character: SimTypes.CharacterSnapshot): Vec
	return character.position
end

local function releasePosition(world: WorldSnapshot, from: Vec, aim: Vec, config: typeof(Combat.Dodgeball)): Vec
	local displacement = aim * config.ReleaseForwardOffset
	local hit = world.collision.sweepSphere(from, displacement, config.Radius)
	if hit then
		return hit.position + hit.normal * config.ContactSeparation
	end
	return from + displacement
end

type CharacterHit = {
	fraction: number,
	position: Vec,
	characterId: string,
}

local function sweepCharacters(
	world: WorldSnapshot,
	from: Vec,
	to: Vec,
	projectile: ProjectileState,
	skipId: string?,
	characterIds: { string }?
): CharacterHit?
	local best: CharacterHit? = nil
	for _, characterId in characterIds or SimUtil.sortedKeys(world.characters) do
		local character = world.characters[characterId]
		if
			characterId == skipId
			or SimUtil.sameTeam(world, skipId, characterId)
			or not character.alive
			or character.invulnerable
		then
			continue
		end
		local capA, capB = CollisionWorld.capsuleEndpoints(character)
		local sumRadius = projectile.effectiveRadius + character.radius
		local hit = CollisionWorld.sweptSphereVsCapsule(from, to, sumRadius, capA, capB)
		if hit and (best == nil or hit.fraction < best.fraction) then
			best = { fraction = hit.fraction, position = hit.position, characterId = characterId }
		end
	end
	return best
end

local function stepHeld(projectile: ProjectileState, world: WorldSnapshot)
	local holder = projectile.heldBy and world.characters[projectile.heldBy :: string]
	if holder == nil or not holder.alive then
		becomeFree(projectile, world, projectile.position)
		return
	end
	projectile.position = holder.handPosition
end

local function stepWindup(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	dt: number,
	events: { SimEvent }
)
	local holder = projectile.heldBy and world.characters[projectile.heldBy :: string]
	if holder == nil or not holder.alive or projectile.releaseAim == nil then
		becomeFree(projectile, world, projectile.position)
		return
	end
	projectile.position = holder.handPosition
	projectile.windupRemaining = math.max(projectile.windupRemaining - dt, 0)
	if projectile.windupRemaining > 0 then
		return
	end

	local row = AimAssist[projectile.releaseDeviceClass or "Mouse"] or AimAssist.Mouse
	local aim = vector.normalize(projectile.releaseAim)
	projectile.phase = "InFlight"
	projectile.heldBy = nil
	projectile.position = releasePosition(world, holder.throwPosition, aim, config)
	projectile.velocity = ProjectileTrajectory.launchVelocity(config, aim, holder.velocity, projectile.releaseCharge)
	projectile.targetId = projectile.releaseTargetId
	projectile.effectiveRadius = config.Radius + config.HitForgiveness + row.MagnetismRadius
	projectile.flightTime = 0
	SimUtil.pushEvent(events, state, {
		kind = "BallReleased",
		tick = 0,
		projectileId = projectile.id,
		playerId = projectile.ownerId,
		targetId = projectile.targetId,
		position = projectile.position,
	})
end

local function maybeSettleAfterBounce(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	hit: SimTypes.SweepHit,
	events: { SimEvent }
)
	local speed = vector.magnitude(projectile.velocity)
	local horizontalSpeed = vector.magnitude(horizontalOf(projectile.velocity))
	local shouldRoll = hit.normal.y > 0.6
		and horizontalSpeed > config.RollSettleSpeed
		and (
			projectile.bounceCount >= config.MaxBounces
			or speed <= config.SettleSpeed
			or math.abs(projectile.velocity.y) <= config.SettleVerticalSpeed
		)
	if shouldRoll then
		beginRolling(projectile, config, projectile.position)
		SimUtil.pushEvent(
			events,
			state,
			{ kind = "BallRolled", tick = 0, projectileId = projectile.id, position = projectile.position }
		)
		return
	end

	if
		projectile.bounceCount >= config.MaxBounces
		or speed <= config.SettleSpeed
		or (hit.normal.y > 0.6 and math.abs(projectile.velocity.y) <= config.SettleVerticalSpeed)
	then
		comeToRest(projectile, state, world, projectile.position, events)
		SimUtil.pushEvent(
			events,
			state,
			{ kind = "BallSettled", tick = 0, projectileId = projectile.id, position = projectile.position }
		)
	end
end

local function decelerateHorizontal(velocity: Vec, decel: number, dt: number): Vec
	local horizontalVelocity = horizontalOf(velocity)
	local speed = vector.magnitude(horizontalVelocity)
	if speed <= 1e-6 then
		return vector.zero
	end
	local nextSpeed = math.max(speed - decel * dt, 0)
	return vector.normalize(horizontalVelocity) * nextSpeed
end

local function bounce(
	projectile: ProjectileState,
	state: SimState,
	config: typeof(Combat.Dodgeball),
	hit: SimTypes.SweepHit,
	events: { SimEvent }
): boolean
	local normalSpeed = vector.dot(projectile.velocity, hit.normal)
	if normalSpeed >= -(config.MinBounceNormalSpeed or DEFAULT_MIN_BOUNCE_NORMAL_SPEED) then
		projectile.position = hit.position + hit.normal * config.ContactSeparation
		if normalSpeed < 0 then
			projectile.velocity -= hit.normal * normalSpeed
		end
		return false
	end

	local normalVelocity = hit.normal * normalSpeed
	local tangentVelocity = projectile.velocity - normalVelocity
	local impactSpeed = -normalSpeed
	projectile.velocity = tangentVelocity * (1 - config.BounceFriction) - normalVelocity * config.BounceRestitution
	projectile.position = hit.position + hit.normal * config.ContactSeparation
	projectile.bounceCount += 1
	projectile.targetId = nil
	projectile.phase = "Bouncing"
	SimUtil.pushEvent(events, state, {
		kind = "BallBounced",
		tick = 0,
		projectileId = projectile.id,
		position = projectile.position,
		normal = hit.normal,
		magnitude = impactSpeed,
	})
	return true
end

local function settleRolling(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	events: { SimEvent }
)
	comeToRest(projectile, state, world, projectile.position, events)
	SimUtil.pushEvent(
		events,
		state,
		{ kind = "BallSettled", tick = 0, projectileId = projectile.id, position = projectile.position }
	)
end

local function advanceBouncing(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	dt: number,
	events: { SimEvent },
	applyGravity: boolean
)
	if dt <= 0 or projectile.phase == "Free" then
		return
	end

	local speed = vector.magnitude(projectile.velocity)
	local substeps = ProjectileTrajectory.substepCount(speed, dt, config.Radius)
	local subDt = dt / substeps
	local maxContacts = config.MaxBounceContactsPerStep or DEFAULT_MAX_CONTACTS_PER_STEP
	local gravity = vector.create(0, -config.Gravity, 0)

	for _ = 1, substeps do
		if applyGravity then
			projectile.velocity += gravity * subDt
		end

		local remaining = subDt
		for _contact = 1, maxContacts do
			local displacement = projectile.velocity * remaining
			local distance = vector.magnitude(displacement)
			if distance <= 1e-6 then
				break
			end

			local hit = world.collision.sweepSphere(projectile.position, displacement, config.Radius)
			if not hit then
				projectile.position += displacement
				break
			end

			local fraction = math.clamp(hit.distance / distance, 0, 1)
			projectile.position = hit.position + hit.normal * config.ContactSeparation
			remaining *= 1 - fraction

			local countedBounce = bounce(projectile, state, config, hit, events)
			if countedBounce then
				maybeSettleAfterBounce(projectile, state, world, config, hit, events)
				if projectile.phase == "Free" then
					return
				end
			end

			if remaining <= 1e-5 then
				break
			end
		end
	end
end

local function stepRolling(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	dt: number,
	events: { SimEvent }
)
	projectile.flightTime += dt
	projectile.velocity = decelerateHorizontal(projectile.velocity, config.RollFriction, dt)
	local speed = vector.magnitude(projectile.velocity)
	if speed <= config.RollSettleSpeed then
		settleRolling(projectile, state, world, config, events)
		return
	end

	local displacement = projectile.velocity * dt
	local hit = world.collision.sweepSphere(projectile.position, displacement, config.Radius)
	if hit then
		if hit.normal.y > 0.6 then
			projectile.position = hit.position + hit.normal * config.ContactSeparation
		else
			local normalSpeed = vector.dot(projectile.velocity, hit.normal)
			local tangentVelocity = projectile.velocity - hit.normal * normalSpeed
			projectile.velocity = tangentVelocity * math.max(0, 1 - config.BounceFriction)
			projectile.position = hit.position + hit.normal * config.ContactSeparation
		end
	else
		projectile.position += displacement
	end

	local snapHit =
		world.collision.sweepSphere(projectile.position, vector.create(0, -config.RollGroundSnap, 0), config.Radius)
	if snapHit and snapHit.normal.y > 0.6 then
		projectile.position = snapHit.position + snapHit.normal * config.ContactSeparation
	end
end

local function stepInFlight(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	dt: number,
	events: { SimEvent }
)
	projectile.flightTime += dt
	if projectile.flightTime > config.MaxFlightTime then
		comeToRest(projectile, state, world, projectile.position, events)
		SimUtil.pushEvent(events, state, { kind = "BallLanded", tick = 0, projectileId = projectile.id })
		return
	end

	local target: SimTypes.CharacterSnapshot? = nil
	if projectile.targetId then
		local candidate = world.characters[projectile.targetId :: string]
		if
			candidate == nil
			or not candidate.alive
			or candidate.invulnerable
			or SimUtil.sameTeam(world, projectile.ownerId, projectile.targetId)
		then
			projectile.targetId = nil
		else
			target = candidate
		end
	end

	local speed = vector.magnitude(projectile.velocity)
	local substeps = ProjectileTrajectory.substepCount(speed, dt, config.Radius)
	local subDt = dt / substeps
	local gravity = vector.create(0, -config.Gravity, 0)
	local characterIds = SimUtil.sortedKeys(world.characters)

	for substepIndex = 1, substeps do
		projectile.velocity += gravity * subDt
		if target then
			projectile.velocity = ProjectileTrajectory.steer(
				projectile.velocity,
				projectile.position,
				chestPosition(target),
				math.rad(config.HomingTurnRateDeg)
					* (AimAssist[projectile.releaseDeviceClass or "Mouse"] or AimAssist.Mouse).HomingTurnScale,
				math.rad(config.HomingBreakAngleDeg),
				subDt
			)
		end

		local from = projectile.position
		local to = from + projectile.velocity * subDt
		local displacement = to - from

		local staticHit = world.collision.sweepSphere(from, displacement, config.Radius)
		local characterHit = sweepCharacters(world, from, to, projectile, projectile.ownerId, characterIds)

		local staticFraction = if staticHit
			then staticHit.distance / math.max(vector.magnitude(displacement), 1e-9)
			else math.huge
		local characterFraction = if characterHit then characterHit.fraction else math.huge

		if characterFraction <= staticFraction and characterHit then
			SimUtil.pushEvent(events, state, {
				kind = "Elim",
				tick = 0,
				projectileId = projectile.id,
				sourceId = projectile.ownerId,
				targetId = characterHit.characterId,
				position = characterHit.position,
				direction = if vector.magnitude(projectile.velocity) > 1e-6
					then vector.normalize(projectile.velocity)
					else nil,
			})
			comeToRest(projectile, state, world, characterHit.position, events)
			return
		end

		if staticHit then
			local displacementDistance = vector.magnitude(displacement)
			local fraction = math.clamp(staticHit.distance / math.max(displacementDistance, 1e-9), 0, 1)
			local countedBounce = bounce(projectile, state, config, staticHit, events)
			if countedBounce then
				maybeSettleAfterBounce(projectile, state, world, config, staticHit, events)
			end
			if projectile.phase == "Bouncing" then
				local remaining = subDt * (1 - fraction) + (substeps - substepIndex) * subDt
				advanceBouncing(projectile, state, world, config, remaining, events, false)
			end
			return
		end

		projectile.position = to
	end
end

local function stepBouncing(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	dt: number,
	events: { SimEvent }
)
	projectile.flightTime += dt
	advanceBouncing(projectile, state, world, config, dt, events, true)
end

function Projectiles.step(state: SimState, world: WorldSnapshot, dt: number, events: { SimEvent })
	local config = Combat.Dodgeball
	for _, id in SimUtil.sortedKeys(state.projectiles) do
		local projectile = state.projectiles[id]
		if projectile.phase == "Held" then
			stepHeld(projectile, world)
		elseif projectile.phase == "Windup" then
			stepWindup(projectile, state, world, config, dt, events)
		elseif projectile.phase == "InFlight" then
			stepInFlight(projectile, state, world, config, dt, events)
		elseif projectile.phase == "Bouncing" then
			stepBouncing(projectile, state, world, config, dt, events)
		elseif projectile.phase == "Rolling" then
			stepRolling(projectile, state, world, config, dt, events)
		end
	end
end

return Projectiles
