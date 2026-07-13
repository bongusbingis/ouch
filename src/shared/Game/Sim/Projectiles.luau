--!strict

local SimTypes = require(script.Parent.SimTypes)
local SimUtil = require(script.Parent.SimUtil)
local CollisionWorld = require(script.Parent.CollisionWorld)
local Combat = require(script.Parent.Parent.Parent.Parent.Config.Combat)
local AimAssist = require(script.Parent.Parent.Parent.Parent.Config.AimAssist)

type Vec = SimTypes.Vec
type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type ProjectileState = SimTypes.ProjectileState
type SimEvent = SimTypes.SimEvent

-- Generic swept-projectile subsystem: fixed-tick kinematics, homing steering,
-- swept-sphere collision vs. capsules and statics, substepped to prevent
-- tunneling. Archetype params come from Config.Combat; the dodgeball is the
-- only archetype for now.

local Projectiles = {}

local MAX_SUBSTEPS = 8
local DEFAULT_MAX_CONTACTS_PER_STEP = 4
local DEFAULT_MIN_BOUNCE_NORMAL_SPEED = 1.5
local SETTLE_DROP = 50

local function pushEvent(events: { SimEvent }, state: SimState, event: SimEvent)
	event.tick = state.tick
	table.insert(events, event)
end

local function settle(world: WorldSnapshot, position: Vec, radius: number): Vec
	local drop = vector.create(0, -SETTLE_DROP, 0)
	local hit = world.collision.sweepSphere(position, drop, radius)
	if hit then
		return hit.position
	end
	return position
end

local function becomeFree(projectile: ProjectileState, world: WorldSnapshot, position: Vec)
	local radius = Combat[projectile.archetype].Radius
	projectile.phase = "Free"
	projectile.position = settle(world, position, radius)
	projectile.velocity = vector.zero
	projectile.targetId = nil
	projectile.heldBy = nil
	projectile.flightTime = 0
	projectile.windupRemaining = 0
	projectile.releaseAim = nil
	projectile.releaseTargetId = nil
	projectile.spinRate = 0
end

local function chestPosition(character: SimTypes.CharacterSnapshot): Vec
	return character.position
end

local function steer(
	velocity: Vec,
	from: Vec,
	targetPos: Vec,
	turnRateRad: number,
	breakAngleRad: number,
	dt: number
): Vec
	local speed = vector.magnitude(velocity)
	if speed <= 1e-6 then
		return velocity
	end
	local currentDir = velocity / speed
	local toTarget = targetPos - from
	if vector.magnitude(toTarget) <= 1e-6 then
		return velocity
	end
	local desiredDir = vector.normalize(toTarget)

	local angleError = math.acos(math.clamp(vector.dot(currentDir, desiredDir), -1, 1))
	local decay = if breakAngleRad > 0 then math.clamp(1 - angleError / breakAngleRad, 0, 1) else 1
	local maxTurn = turnRateRad * decay * dt
	return CollisionWorld.rotateToward(currentDir, desiredDir, maxTurn) * speed
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
	skipId: string?
): CharacterHit?
	local best: CharacterHit? = nil
	for _, characterId in SimUtil.sortedKeys(world.characters) do
		local character = world.characters[characterId]
		if characterId == skipId or not character.alive then
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
	projectile.position = holder.handPosition + aim * config.ReleaseForwardOffset
	projectile.velocity = aim * config.ThrowSpeed + holder.velocity * config.MomentumInheritance
	projectile.targetId = projectile.releaseTargetId
	projectile.effectiveRadius = config.Radius + config.HitForgiveness + row.MagnetismRadius
	projectile.spinRate = config.SpinRate
	projectile.flightTime = 0
	pushEvent(events, state, {
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
	if
		projectile.bounceCount >= config.MaxBounces
		or speed <= config.SettleSpeed
		or (hit.normal.y > 0.6 and math.abs(projectile.velocity.y) <= config.SettleVerticalSpeed)
	then
		becomeFree(projectile, world, projectile.position)
		pushEvent(
			events,
			state,
			{ kind = "BallSettled", tick = 0, projectileId = projectile.id, position = projectile.position }
		)
	end
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
	projectile.velocity = tangentVelocity * (1 - config.BounceFriction) - normalVelocity * config.BounceRestitution
	projectile.position = hit.position + hit.normal * config.ContactSeparation
	projectile.bounceCount += 1
	projectile.targetId = nil
	projectile.phase = "Bouncing"
	pushEvent(events, state, {
		kind = "BallBounced",
		tick = 0,
		projectileId = projectile.id,
		position = projectile.position,
		normal = hit.normal,
	})
	return true
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
	local substeps = math.clamp(math.ceil(speed * dt / math.max(config.Radius, 0.5)), 1, MAX_SUBSTEPS)
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
		becomeFree(projectile, world, projectile.position)
		pushEvent(events, state, { kind = "BallLanded", tick = 0, projectileId = projectile.id })
		return
	end

	local target = projectile.targetId and world.characters[projectile.targetId :: string]
	if target ~= nil and not target.alive then
		target = nil
		projectile.targetId = nil
	end

	local speed = vector.magnitude(projectile.velocity)
	local substeps = math.clamp(math.ceil(speed * dt / math.max(config.Radius, 0.5)), 1, MAX_SUBSTEPS)
	local subDt = dt / substeps
	local gravity = vector.create(0, -config.Gravity, 0)

	for substepIndex = 1, substeps do
		projectile.velocity += gravity * subDt
		if target then
			projectile.velocity = steer(
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
		local characterHit = sweepCharacters(world, from, to, projectile, projectile.ownerId)

		local staticFraction = if staticHit
			then staticHit.distance / math.max(vector.magnitude(displacement), 1e-9)
			else math.huge
		local characterFraction = if characterHit then characterHit.fraction else math.huge

		if characterFraction <= staticFraction and characterHit then
			pushEvent(events, state, {
				kind = "Elim",
				tick = 0,
				projectileId = projectile.id,
				sourceId = projectile.ownerId,
				targetId = characterHit.characterId,
			})
			becomeFree(projectile, world, characterHit.position)
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

local function stepRecalling(
	projectile: ProjectileState,
	state: SimState,
	world: WorldSnapshot,
	config: typeof(Combat.Dodgeball),
	dt: number,
	events: { SimEvent }
)
	local owner = projectile.ownerId and world.characters[projectile.ownerId :: string]
	if owner == nil or not owner.alive then
		becomeFree(projectile, world, projectile.position)
		return
	end

	local ownerPos = owner.handPosition
	if vector.magnitude(ownerPos - projectile.position) <= config.PickupRadius then
		projectile.phase = "Held"
		projectile.heldBy = projectile.ownerId
		projectile.position = ownerPos
		projectile.velocity = vector.zero
		projectile.targetId = nil
		pushEvent(
			events,
			state,
			{ kind = "BallRecalled", tick = 0, projectileId = projectile.id, playerId = projectile.ownerId }
		)
		return
	end

	local toOwner = ownerPos - projectile.position
	local desired = vector.normalize(toOwner) * config.RecallSpeed
	local delta = desired - projectile.velocity
	local maxDelta = config.RecallAcceleration * dt
	projectile.velocity += if vector.magnitude(delta) > maxDelta then vector.normalize(delta) * maxDelta else delta
	-- Recalling balls pass through everything; interception is a playtest toggle.
	if config.RecallInterceptable then
		local to = projectile.position + projectile.velocity * dt
		local hit = sweepCharacters(world, projectile.position, to, projectile, projectile.ownerId)
		if hit then
			becomeFree(projectile, world, hit.position)
			return
		end
	end
	projectile.position += projectile.velocity * dt
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
		elseif projectile.phase == "Recalling" then
			stepRecalling(projectile, state, world, config, dt, events)
		end
		if projectile.phase == "InFlight" or projectile.phase == "Bouncing" or projectile.phase == "Recalling" then
			projectile.spinAngle = (projectile.spinAngle + projectile.spinRate * dt) % (math.pi * 2)
		end
	end
end

return Projectiles
