-- Description: Pure projectile kinematics shared by the authoritative sim and the client's aim preview: launch speed and velocity, substep counts, homing steering, and sampling a predicted path.

--!strict

local SimTypes = require(script.Parent.SimTypes)
local CollisionWorld = require(script.Parent.CollisionWorld)

type Vec = SimTypes.Vec

export type LaunchSpeedConfig = {
	ThrowSpeed: number,
	Charge: {
		MaxSpeedScale: number,
	},
}

export type LaunchVelocityConfig = LaunchSpeedConfig & {
	MomentumInheritance: number,
}

export type HomingTarget = {
	position: Vec,
	velocity: Vec,
}

export type SampleParams = {
	origin: Vec,
	velocity: Vec,
	gravity: Vec,
	duration: number,
	radius: number,
	sampleCount: number,
	target: HomingTarget?,
	turnRateRad: number?,
	breakAngleRad: number?,
}

local ProjectileTrajectory = {}

ProjectileTrajectory.FixedDt = 1 / 60
ProjectileTrajectory.MaxSamples = 128

local MAX_SUBSTEPS = 8
local EPSILON = 1e-9

function ProjectileTrajectory.launchSpeed(config: LaunchSpeedConfig, charge: number?): number
	local clampedCharge = math.clamp(charge or 0, 0, 1)
	return config.ThrowSpeed * (1 + (config.Charge.MaxSpeedScale - 1) * clampedCharge)
end

function ProjectileTrajectory.launchVelocity(
	config: LaunchVelocityConfig,
	aimDirection: Vec,
	carrierVelocity: Vec,
	charge: number?
): Vec
	return aimDirection * ProjectileTrajectory.launchSpeed(config, charge)
		+ carrierVelocity * config.MomentumInheritance
end

function ProjectileTrajectory.substepCount(speed: number, dt: number, radius: number): number
	return math.clamp(math.ceil(speed * dt / math.max(radius, 0.5)), 1, MAX_SUBSTEPS)
end

function ProjectileTrajectory.steer(
	velocity: Vec,
	from: Vec,
	targetPosition: Vec,
	turnRateRad: number,
	breakAngleRad: number,
	dt: number
): Vec
	local speed = vector.magnitude(velocity)
	if speed <= 1e-6 then
		return velocity
	end
	local currentDirection = velocity / speed
	local toTarget = targetPosition - from
	if vector.magnitude(toTarget) <= 1e-6 then
		return velocity
	end
	local desiredDirection = vector.normalize(toTarget)

	local angleError = math.acos(math.clamp(vector.dot(currentDirection, desiredDirection), -1, 1))
	local decay = if breakAngleRad > 0 then math.clamp(1 - angleError / breakAngleRad, 0, 1) else 1
	local maxTurn = turnRateRad * decay * dt
	return CollisionWorld.rotateToward(currentDirection, desiredDirection, maxTurn) * speed
end

function ProjectileTrajectory.sampleInto(params: SampleParams, output: { Vec }): number
	table.clear(output)
	local requested = math.clamp(math.floor(params.sampleCount), 0, ProjectileTrajectory.MaxSamples)
	if requested == 0 then
		return 0
	end

	local duration = math.max(params.duration, 0)
	local position = params.origin
	local velocity = params.velocity
	output[1] = position
	if requested == 1 or duration <= EPSILON then
		return 1
	end

	local sampleInterval = duration / (requested - 1)
	local nextSample = 2
	local elapsed = 0
	local gravity = params.gravity
	local target = params.target
	local turnRateRad = params.turnRateRad or 0
	local breakAngleRad = params.breakAngleRad or 0

	while elapsed < duration - EPSILON and nextSample <= requested do
		local tickStart = elapsed
		local tickDt = math.min(ProjectileTrajectory.FixedDt, duration - tickStart)
		local targetPosition = if target then target.position + target.velocity * tickStart else vector.zero
		local substeps = ProjectileTrajectory.substepCount(vector.magnitude(velocity), tickDt, params.radius)
		local subDt = tickDt / substeps

		for _ = 1, substeps do
			local from = position
			local stepStart = elapsed
			velocity += gravity * subDt
			if target then
				velocity =
					ProjectileTrajectory.steer(velocity, position, targetPosition, turnRateRad, breakAngleRad, subDt)
			end
			position += velocity * subDt
			elapsed = stepStart + subDt

			while nextSample <= requested do
				local sampleTime = sampleInterval * (nextSample - 1)
				if sampleTime > elapsed + EPSILON then
					break
				end
				local alpha = math.clamp((sampleTime - stepStart) / subDt, 0, 1)
				output[nextSample] = from + (position - from) * alpha
				nextSample += 1
			end
		end
	end

	while nextSample <= requested do
		output[nextSample] = position
		nextSample += 1
	end
	return requested
end

return ProjectileTrajectory
