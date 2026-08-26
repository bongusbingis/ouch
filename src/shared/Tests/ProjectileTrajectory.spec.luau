-- Name: ProjectileTrajectory.spec.luau
-- Author: Jack C.
-- Description: Spec that the shared trajectory sampler matches the authoritative simulation exactly for gravity, homing, carrier momentum, and charged release, and respects its buffer and substep bounds.
-- Created: 2026-08-24

--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local Sim = script.Parent.Parent.Game.Sim
local SimTypes = require(Sim.SimTypes)
local Projectiles = require(Sim.Projectiles)
local ProjectileTrajectory = require(Sim.ProjectileTrajectory)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)
local AimAssist = require(script.Parent.Parent.Parent.Config.AimAssist)

type Vec = SimTypes.Vec
type ProjectileState = SimTypes.ProjectileState

local DT = ProjectileTrajectory.FixedDt

local function expectVectorNear(actual: Vec, expected: Vec, epsilon: number?)
	local tolerance = epsilon or 1e-5
	T.expect(actual.x):toBeNear(expected.x, tolerance)
	T.expect(actual.y):toBeNear(expected.y, tolerance)
	T.expect(actual.z):toBeNear(expected.z, tolerance)
end

local function makeBall(state: SimTypes.SimState, fields: { [string]: any }): ProjectileState
	local ball: ProjectileState = {
		id = "ball_0001",
		archetype = "Dodgeball",
		ownerId = fields.ownerId,
		heldBy = fields.heldBy,
		phase = fields.phase or "InFlight",
		position = fields.position or vector.zero,
		velocity = fields.velocity or vector.zero,
		targetId = fields.targetId,
		effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
		flightTime = 0,
		windupRemaining = fields.windupRemaining or 0,
		bounceCount = 0,
		releaseAim = fields.releaseAim,
		releaseCharge = fields.releaseCharge,
		releaseTargetId = fields.releaseTargetId,
		releaseDeviceClass = fields.releaseDeviceClass,
	}
	state.projectiles[ball.id] = ball
	return ball
end

T.describe("ProjectileTrajectory", function()
	T.it("clamps charge while scaling launch speed continuously", function()
		local base = ProjectileTrajectory.launchSpeed(Combat.Dodgeball, 0)
		local half = ProjectileTrajectory.launchSpeed(Combat.Dodgeball, 0.5)
		local full = ProjectileTrajectory.launchSpeed(Combat.Dodgeball, 1)
		T.expect(base):toBeNear(Combat.Dodgeball.ThrowSpeed, 1e-6)
		T.expect(half):toBeNear((base + full) / 2, 1e-6)
		T.expect(ProjectileTrajectory.launchSpeed(Combat.Dodgeball, -4)):toBeNear(base, 1e-6)
		T.expect(ProjectileTrajectory.launchSpeed(Combat.Dodgeball, 4)):toBeNear(full, 1e-6)
	end)

	T.it("includes inherited carrier velocity in the launch", function()
		local aim = vector.normalize(vector.create(1, 0.25, -0.1))
		local carrier = vector.create(12, 5, -8)
		local charge = 0.65
		local expected = aim * ProjectileTrajectory.launchSpeed(Combat.Dodgeball, charge)
			+ carrier * Combat.Dodgeball.MomentumInheritance
		expectVectorNear(ProjectileTrajectory.launchVelocity(Combat.Dodgeball, aim, carrier, charge), expected)
	end)

	T.it("uses the authoritative substep bounds", function()
		T.expect(ProjectileTrajectory.substepCount(0, DT, 1)):toEqual(1)
		T.expect(ProjectileTrajectory.substepCount(140, DT, 1)):toEqual(3)
		T.expect(ProjectileTrajectory.substepCount(10000, DT, 1)):toEqual(8)
		T.expect(ProjectileTrajectory.substepCount(140, DT, 0.1)):toEqual(5)
	end)

	T.it("reuses the caller buffer and caps its sample count", function()
		local output = { vector.one, vector.one, vector.one }
		local count = ProjectileTrajectory.sampleInto({
			origin = vector.zero,
			velocity = vector.create(100, 0, 0),
			gravity = vector.create(0, -70, 0),
			duration = 2,
			radius = 1,
			sampleCount = 1000,
		}, output)
		T.expect(count):toEqual(ProjectileTrajectory.MaxSamples)
		T.expect(#output):toEqual(ProjectileTrajectory.MaxSamples)
		expectVectorNear(output[1], vector.zero)

		T.expect(ProjectileTrajectory.sampleInto({
			origin = vector.zero,
			velocity = vector.zero,
			gravity = vector.zero,
			duration = 1,
			radius = 1,
			sampleCount = 0,
		}, output)):toEqual(0)
		T.expect(#output):toEqual(0)
	end)

	T.it("matches authoritative fixed-step gravity at every tick", function()
		local ticks = 30
		local origin = vector.create(-3, 8, 2)
		local velocity = ProjectileTrajectory.launchVelocity(
			Combat.Dodgeball,
			vector.normalize(vector.create(1, 0.18, 0.25)),
			vector.create(10, 0, -4),
			0.5
		)
		local samples: { Vec } = {}
		ProjectileTrajectory.sampleInto({
			origin = origin,
			velocity = velocity,
			gravity = vector.create(0, -Combat.Dodgeball.Gravity, 0),
			duration = ticks * DT,
			radius = Combat.Dodgeball.Radius,
			sampleCount = ticks + 1,
		}, samples)

		local state = SimTypes.newState()
		local ball = makeBall(state, { position = origin, velocity = velocity, ownerId = "shooter" })
		local world = MockWorld.snapshot({})
		expectVectorNear(samples[1], ball.position)
		for tick = 1, ticks do
			Projectiles.step(state, world, DT, {})
			expectVectorNear(samples[tick + 1], ball.position, 1e-4)
		end
	end)

	T.it("matches an authoritative constant-velocity homing target", function()
		local ticks = 18
		local origin = vector.create(0, 3, 0)
		local velocity = vector.create(Combat.Dodgeball.ThrowSpeed, 0, 0)
		local targetOrigin = vector.create(80, 3, 25)
		local targetVelocity = vector.create(0, 0, 8)
		local device = "Gamepad"
		local row = AimAssist[device]
		local samples: { Vec } = {}
		ProjectileTrajectory.sampleInto({
			origin = origin,
			velocity = velocity,
			gravity = vector.create(0, -Combat.Dodgeball.Gravity, 0),
			duration = ticks * DT,
			radius = Combat.Dodgeball.Radius,
			sampleCount = ticks + 1,
			target = { position = targetOrigin, velocity = targetVelocity },
			turnRateRad = math.rad(Combat.Dodgeball.HomingTurnRateDeg) * row.HomingTurnScale,
			breakAngleRad = math.rad(Combat.Dodgeball.HomingBreakAngleDeg),
		}, samples)

		local state = SimTypes.newState()
		local ball = makeBall(state, {
			position = origin,
			velocity = velocity,
			ownerId = "shooter",
			targetId = "target",
			releaseDeviceClass = device,
		})
		local target = MockWorld.character(targetOrigin, { velocity = targetVelocity })
		local world = MockWorld.snapshot({ target = target })
		for tick = 1, ticks do
			target.position = targetOrigin + targetVelocity * ((tick - 1) * DT)
			Projectiles.step(state, world, DT, {})
			expectVectorNear(samples[tick + 1], ball.position, 1e-4)
		end
	end)

	T.it("matches the authoritative charged release including momentum", function()
		local state = SimTypes.newState()
		local owner = MockWorld.character(vector.create(0, 2.5, 0), {
			handPosition = vector.create(0, 4, 0),
			throwPosition = vector.create(0.5, 4.2, -0.5),
			velocity = vector.create(14, 3, -7),
		})
		local world = MockWorld.snapshot({ owner = owner })
		local aim = vector.normalize(vector.create(1, 0.15, 0.2))
		local charge = 0.7
		local ball = makeBall(state, {
			phase = "Windup",
			heldBy = "owner",
			ownerId = "owner",
			position = owner.handPosition,
			releaseAim = aim,
			releaseCharge = charge,
			windupRemaining = 0,
		})

		Projectiles.step(state, world, DT, {})

		T.expect(ball.phase):toEqual("InFlight")
		expectVectorNear(
			ball.velocity,
			ProjectileTrajectory.launchVelocity(Combat.Dodgeball, aim, owner.velocity, charge),
			1e-5
		)
	end)
end)

return true
