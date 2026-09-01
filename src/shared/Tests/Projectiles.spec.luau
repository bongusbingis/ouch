-- Name: Projectiles.spec.luau
-- Author: Jack C.
-- Description: Spec for the projectile subsystem: straight flight and flight-time limits, determinism, homing clamps and lock breaking, no tunneling through thin walls, bounce and roll settling, and charged release speeds.
-- Created: 2026-07-12

--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local Projectiles = require(script.Parent.Parent.Game.Sim.Projectiles)
local Combat = require(script.Parent.Parent.Parent.Config.Gameplay.Combat)

type ProjectileState = SimTypes.ProjectileState

local DT = 1 / 60

local function withConfig(overrides: { [string]: any }, fn: () -> ())
	local cfg = Combat.Dodgeball :: { [string]: any }
	local saved = {}
	for key, value in overrides do
		saved[key] = cfg[key]
		cfg[key] = value
	end
	local ok, err = pcall(fn)
	for key, value in saved do
		cfg[key] = value
	end
	if not ok then
		error(err, 2)
	end
end

local function makeBall(state: SimTypes.SimState, fields: { [string]: any }): ProjectileState
	local ball: ProjectileState = {
		id = fields.id or "ball_0001",
		archetype = "Dodgeball",
		ownerId = fields.ownerId,
		heldBy = fields.heldBy,
		phase = fields.phase or "InFlight",
		position = fields.position or vector.zero,
		velocity = fields.velocity or vector.zero,
		targetId = fields.targetId,
		effectiveRadius = fields.effectiveRadius or (Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness),
		flightTime = 0,
		windupRemaining = fields.windupRemaining or 0,
		bounceCount = fields.bounceCount or 0,
		releaseAim = fields.releaseAim,
		releaseCharge = fields.releaseCharge,
		releaseTargetId = fields.releaseTargetId,
		releaseDeviceClass = fields.releaseDeviceClass,
	}
	state.projectiles[ball.id] = ball
	return ball
end

local function angleBetween(a: vector, b: vector): number
	return math.acos(math.clamp(vector.dot(vector.normalize(a), vector.normalize(b)), -1, 1))
end

T.describe("Projectiles", function()
	T.it("flies straight and lands within max flight time", function()
		withConfig({ Gravity = 0, MaxFlightTime = 3 }, function()
			local state = SimTypes.newState()
			local world = MockWorld.snapshot({}, { MockWorld.ground() })
			local ball = makeBall(state, {
				position = vector.create(0, 10, 0),
				velocity = vector.create(80, 0, 0),
			})
			local events = {}
			for _ = 1, math.ceil(Combat.Dodgeball.MaxFlightTime / DT) + 1 do
				Projectiles.step(state, world, DT, events)
			end
			T.expect(ball.phase == "Bouncing" or ball.phase == "Free"):toBeTruthy()
			T.expect(ball.position.y):toBeNear(Combat.Dodgeball.Radius, 1e-3)
			T.expect(ball.position.x > 200):toBeTruthy()
		end)
	end)

	T.it("is deterministic across identical runs", function()
		local function run(): (vector, number)
			local state = SimTypes.newState()
			local target = MockWorld.character(vector.create(40, 2.5, 6))
			local world = MockWorld.snapshot({ dummy = target }, { MockWorld.ground() })
			local ball = makeBall(state, {
				position = vector.create(0, 3, 0),
				velocity = vector.create(80, 2, 0),
				targetId = "dummy",
				ownerId = "shooter",
			})
			local events = {}
			for _ = 1, 90 do
				Projectiles.step(state, world, DT, events)
			end
			return ball.position, #events
		end

		local posA, eventsA = run()
		local posB, eventsB = run()
		T.expect(posA == posB):toBeTruthy()
		T.expect(eventsA):toEqual(eventsB)
	end)

	T.it("clamps homing turn rate per tick", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local target = MockWorld.character(vector.create(30, 3, 5))
			local world = MockWorld.snapshot({ dummy = target })
			local ball = makeBall(state, {
				position = vector.create(0, 3, 0),
				velocity = vector.create(80, 0, 0),
				targetId = "dummy",
				ownerId = "shooter",
			})
			local before = ball.velocity
			Projectiles.step(state, world, DT, {})
			local turned = angleBetween(before, ball.velocity)
			T.expect(turned <= math.rad(Combat.Dodgeball.HomingTurnRateDeg) * DT + 1e-4):toBeTruthy()
			T.expect(turned > 0):toBeTruthy()
		end)
	end)

	T.it("breaks lock past the break angle", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local target = MockWorld.character(vector.create(0, 3, 30))
			local world = MockWorld.snapshot({ dummy = target })
			local ball = makeBall(state, {
				position = vector.create(0, 3, 0),
				velocity = vector.create(80, 0, 0),
				targetId = "dummy",
				ownerId = "shooter",
			})
			local before = ball.velocity
			Projectiles.step(state, world, DT, {})
			T.expect(angleBetween(before, ball.velocity)):toBeNear(0, 1e-5)
		end)
	end)

	T.it("does not tunnel through thin walls at high speed", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local thinWall = {
				min = vector.create(30, -10, -20),
				max = vector.create(30.2, 20, 20),
			}
			local world = MockWorld.snapshot({}, { MockWorld.ground(), thinWall })
			local ball = makeBall(state, {
				position = vector.create(0, 5, 0),
				velocity = vector.create(240, 0, 0),
			})
			local events = {}
			for _ = 1, 20 do
				Projectiles.step(state, world, DT, events)
			end
			T.expect(ball.phase == "Bouncing" or ball.phase == "Free"):toBeTruthy()
			T.expect(ball.position.x < 30):toBeTruthy()
		end)
	end)

	T.it("rebounds away from vertical walls instead of sticking", function()
		withConfig({ Gravity = 0, MaxBounces = 3, BounceRestitution = 0.7, BounceFriction = 0.1 }, function()
			local state = SimTypes.newState()
			local wall = {
				min = vector.create(20, -10, -20),
				max = vector.create(21, 20, 20),
			}
			local world = MockWorld.snapshot({}, { wall })
			local ball = makeBall(state, {
				position = vector.create(0, 5, 0),
				velocity = vector.create(180, 0, 0),
			})
			local events: { SimTypes.SimEvent } = {}
			for _ = 1, 10 do
				Projectiles.step(state, world, DT, events)
				if ball.bounceCount > 0 then
					break
				end
			end

			T.expect(ball.phase):toEqual("Bouncing")
			T.expect(ball.bounceCount):toEqual(1)
			T.expect(ball.velocity.x < 0):toBeTruthy()
			T.expect(ball.position.x < 20 - Combat.Dodgeball.Radius):toBeTruthy()

			local afterBounceX = ball.position.x
			Projectiles.step(state, world, DT, events)
			T.expect(ball.position.x < afterBounceX):toBeTruthy()
		end)
	end)

	T.it("preserves damped tangential wall motion on rebound", function()
		withConfig({ Gravity = 0, BounceRestitution = 0.7, BounceFriction = 0.25 }, function()
			local state = SimTypes.newState()
			local wall = {
				min = vector.create(20, -10, -20),
				max = vector.create(21, 20, 20),
			}
			local world = MockWorld.snapshot({}, { wall })
			local ball = makeBall(state, {
				position = vector.create(0, 5, 0),
				velocity = vector.create(180, 0, 60),
			})

			for _ = 1, 10 do
				Projectiles.step(state, world, DT, {})
				if ball.bounceCount > 0 then
					break
				end
			end

			T.expect(ball.velocity.x < 0):toBeTruthy()
			T.expect(ball.velocity.z):toBeNear(45, 1e-3)
		end)
	end)

	T.it("settles after the configured maximum bounce count", function()
		withConfig({
			Gravity = 0,
			MaxBounces = 2,
			BounceRestitution = 1,
			BounceFriction = 0,
			SettleSpeed = 0,
			SettleVerticalSpeed = 0,
		}, function()
			local state = SimTypes.newState()
			local leftWall = {
				min = vector.create(-21, -10, -20),
				max = vector.create(-20, 20, 20),
			}
			local rightWall = {
				min = vector.create(20, -10, -20),
				max = vector.create(21, 20, 20),
			}
			local world = MockWorld.snapshot({}, { MockWorld.ground(), leftWall, rightWall })
			local ball = makeBall(state, {
				position = vector.create(0, 5, 0),
				velocity = vector.create(240, 0, 0),
			})
			local events: { SimTypes.SimEvent } = {}

			for _ = 1, 60 do
				Projectiles.step(state, world, DT, events)
				if ball.phase == "Free" then
					break
				end
			end

			local bounceEvents = 0
			local settleEvents = 0
			for _, event in events do
				if event.kind == "BallBounced" then
					bounceEvents += 1
				elseif event.kind == "BallSettled" then
					settleEvents += 1
				end
			end

			T.expect(ball.phase):toEqual("Free")
			T.expect(ball.bounceCount):toEqual(2)
			T.expect(bounceEvents):toEqual(2)
			T.expect(settleEvents):toEqual(1)
		end)
	end)

	T.it("rolls after the final floor bounce before settling", function()
		withConfig({
			Gravity = 80,
			MaxBounces = 1,
			BounceRestitution = 0.2,
			BounceFriction = 0.1,
			SettleSpeed = 0,
			SettleVerticalSpeed = 0,
			RollFriction = 20,
			RollSettleSpeed = 2,
		}, function()
			local state = SimTypes.newState()
			local world = MockWorld.snapshot({}, { MockWorld.ground() })
			local ball = makeBall(state, {
				position = vector.create(0, 5, 0),
				velocity = vector.create(35, -45, 0),
			})
			local events: { SimTypes.SimEvent } = {}

			for _ = 1, 60 do
				Projectiles.step(state, world, DT, events)
				if ball.phase == "Rolling" then
					break
				end
			end

			T.expect(ball.phase):toEqual("Rolling")
			T.expect(ball.velocity.x > 0):toBeTruthy()
			T.expect(math.abs(ball.velocity.y)):toBeNear(0, 1e-5)
			local rollingX = ball.position.x

			for _ = 1, 10 do
				Projectiles.step(state, world, DT, events)
			end
			T.expect(ball.position.x > rollingX):toBeTruthy()

			for _ = 1, 180 do
				Projectiles.step(state, world, DT, events)
				if ball.phase == "Free" then
					break
				end
			end

			local rolled = false
			local settled = false
			for _, event in events do
				if event.kind == "BallRolled" then
					rolled = true
				elseif event.kind == "BallSettled" then
					settled = true
				end
			end

			T.expect(ball.phase):toEqual("Free")
			T.expect(rolled):toBeTruthy()
			T.expect(settled):toBeTruthy()
		end)
	end)

	T.it("clears the floor on steep downward overhand release", function()
		withConfig({
			Gravity = 50,
			BounceRestitution = 0.55,
			BounceFriction = 0.1,
			MaxBounces = 3,
		}, function()
			local state = SimTypes.newState()
			local owner = MockWorld.character(vector.create(0, 2.5, 0), {
				handPosition = vector.create(0, 1.2, 0),
				throwPosition = vector.create(0, 1.2, 0),
			})
			local world = MockWorld.snapshot({ owner = owner }, { MockWorld.ground() })
			local aim = vector.normalize(vector.create(0.25, -1, 0))
			local ball = makeBall(state, {
				phase = "Windup",
				heldBy = "owner",
				ownerId = "owner",
				position = owner.handPosition,
				releaseAim = aim,
				windupRemaining = 0,
			})
			local events: { SimTypes.SimEvent } = {}

			Projectiles.step(state, world, DT, events)
			T.expect(ball.phase):toEqual("InFlight")
			T.expect(ball.position.y >= Combat.Dodgeball.Radius):toBeTruthy()

			for _ = 1, 10 do
				Projectiles.step(state, world, DT, events)
				if ball.bounceCount > 0 then
					break
				end
			end

			T.expect(ball.bounceCount > 0):toBeTruthy()
			T.expect(ball.phase == "Bouncing" or ball.phase == "Rolling"):toBeTruthy()
		end)
	end)

	local function release(fields: { [string]: any }): ProjectileState
		local state = SimTypes.newState()
		local owner = MockWorld.character(vector.create(0, 2.5, 0), {
			handPosition = vector.create(0, 1.2, 0),
			throwPosition = vector.create(0, 1.2, 0),
		})
		local world = MockWorld.snapshot({ owner = owner }, {})
		local ball = makeBall(state, {
			phase = "Windup",
			heldBy = "owner",
			ownerId = "owner",
			position = owner.handPosition,
			releaseAim = vector.create(0, 0, 1),
			windupRemaining = 0,
			releaseCharge = fields.releaseCharge,
		})
		local events: { SimTypes.SimEvent } = {}
		Projectiles.step(state, world, DT, events)
		return ball
	end

	T.it("releases an uncharged throw at the configured speed", function()
		local ball = release({})
		T.expect(vector.magnitude(ball.velocity)):toBeNear(Combat.Dodgeball.ThrowSpeed, 1e-3)
	end)

	T.it("throws a fully charged ball faster", function()
		local ball = release({ releaseCharge = 1 })
		local expected = Combat.Dodgeball.ThrowSpeed * Combat.Dodgeball.Charge.MaxSpeedScale
		T.expect(vector.magnitude(ball.velocity)):toBeNear(expected, 1e-3)
	end)

	T.it("scales charge speed continuously rather than in steps", function()
		local half = vector.magnitude(release({ releaseCharge = 0.5 }).velocity)
		local none = vector.magnitude(release({}).velocity)
		local full = vector.magnitude(release({ releaseCharge = 1 }).velocity)
		T.expect(half > none and half < full):toBeTruthy()
	end)

	T.it("does not let an out-of-range charge exceed the full-charge throw", function()
		local full = vector.magnitude(release({ releaseCharge = 1 }).velocity)
		T.expect(vector.magnitude(release({ releaseCharge = 5 }).velocity)):toBeNear(full, 1e-3)
	end)

	T.it("releases flat along the aim the player gave", function()
		local flat = release({})
		T.expect(flat.velocity.y):toBeNear(0, 1e-4)
		T.expect(vector.normalize(flat.velocity).x):toBeNear(0, 1e-4)
	end)

	T.it("holds at the fake held socket during windup", function()
		local state = SimTypes.newState()
		local owner = MockWorld.character(vector.create(0, 2.5, 0), {
			handPosition = vector.create(2, 3, -1),
			throwPosition = vector.create(2, 5, -1),
		})
		local world = MockWorld.snapshot({ owner = owner })
		local ball = makeBall(state, {
			phase = "Windup",
			heldBy = "owner",
			ownerId = "owner",
			position = vector.zero,
			releaseAim = vector.create(1, 0, 0),
			windupRemaining = 0.2,
		})

		Projectiles.step(state, world, DT, {})

		T.expect(ball.phase):toEqual("Windup")
		T.expect(ball.position):toEqual(owner.handPosition)
	end)

	T.it("releases from the overhand socket with the configured forward offset", function()
		withConfig({ Gravity = 0, ReleaseForwardOffset = 1.25 }, function()
			local state = SimTypes.newState()
			local owner = MockWorld.character(vector.create(0, 2.5, 0), {
				handPosition = vector.create(2, 4, -1),
				throwPosition = vector.create(2, 6, -1),
			})
			local world = MockWorld.snapshot({ owner = owner })
			local aim = vector.create(1, 0, 0)
			local ball = makeBall(state, {
				phase = "Windup",
				heldBy = "owner",
				ownerId = "owner",
				position = owner.handPosition,
				releaseAim = aim,
				windupRemaining = 0,
			})

			Projectiles.step(state, world, DT, {})

			T.expect(ball.phase):toEqual("InFlight")
			T.expect(ball.position):toEqual(owner.throwPosition + aim * 1.25)
		end)
	end)

	T.it("eliminates a character in the flight path exactly once", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local target = MockWorld.character(vector.create(20, 3, 0))
			local world = MockWorld.snapshot({ dummy = target }, { MockWorld.ground() })
			makeBall(state, {
				position = vector.create(0, 3, 0),
				velocity = vector.create(80, 0, 0),
				ownerId = "shooter",
			})
			local events: { SimTypes.SimEvent } = {}
			for _ = 1, 60 do
				Projectiles.step(state, world, DT, events)
			end
			local elims = 0
			for _, event in events do
				if event.kind == "Elim" then
					elims += 1
					T.expect(event.targetId):toEqual("dummy")
					T.expect(event.sourceId):toEqual("shooter")
					T.expect(event.direction):toEqual(vector.create(1, 0, 0))
				end
			end
			T.expect(elims):toEqual(1)
		end)
	end)

	T.it("passes through invulnerable characters without eliminating them", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local target = MockWorld.character(vector.create(20, 3, 0), { invulnerable = true })
			local world = MockWorld.snapshot({ dummy = target }, { MockWorld.ground() })
			makeBall(state, {
				position = vector.create(0, 3, 0),
				velocity = vector.create(80, 0, 0),
				ownerId = "shooter",
			})
			local events: { SimTypes.SimEvent } = {}
			for _ = 1, 60 do
				Projectiles.step(state, world, DT, events)
			end
			for _, event in events do
				T.expect(event.kind == "Elim"):toEqual(false)
			end
		end)
	end)

	T.it("passes through teammates without eliminating them", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local owner = MockWorld.character(vector.create(0, 3, 0), { teamId = "Red" })
			local teammate = MockWorld.character(vector.create(20, 3, 0), { teamId = "Red" })
			local enemy = MockWorld.character(vector.create(40, 3, 0), { teamId = "Blue" })
			local world = MockWorld.snapshot(
				{ shooter = owner, teammate = teammate, enemy = enemy },
				{ MockWorld.ground() }
			)
			makeBall(state, {
				position = vector.create(0, 3, 0),
				velocity = vector.create(80, 0, 0),
				ownerId = "shooter",
			})
			local events: { SimTypes.SimEvent } = {}
			for _ = 1, 60 do
				Projectiles.step(state, world, DT, events)
			end
			for _, event in events do
				if event.kind == "Elim" then
					T.expect(event.targetId):toEqual("enemy")
				end
			end
		end)
	end)

	T.it("never hits its own thrower while in flight", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local shooter = MockWorld.character(vector.create(0, 3, 0))
			local world = MockWorld.snapshot({ shooter = shooter }, { MockWorld.ground() })
			makeBall(state, {
				position = vector.create(0, 3, 0),
				velocity = vector.create(80, 0, 0),
				ownerId = "shooter",
			})
			local events: { SimTypes.SimEvent } = {}
			for _ = 1, 30 do
				Projectiles.step(state, world, DT, events)
			end
			for _, event in events do
				T.expect(event.kind == "Elim"):toEqual(false)
			end
		end)
	end)

	T.it("reports impact speed on bounce events for presentation intensity", function()
		withConfig({ Gravity = 0 }, function()
			local state = SimTypes.newState()
			local wall = {
				min = vector.create(5, -10, -10),
				max = vector.create(6, 10, 10),
			}
			makeBall(state, {
				position = vector.create(0, 2, 0),
				velocity = vector.create(60, 0, 0),
			})
			local events: { SimTypes.SimEvent } = {}
			for _ = 1, 10 do
				Projectiles.step(state, MockWorld.snapshot({}, { wall }), DT, events)
			end
			local magnitude = 0
			for _, event in events do
				if event.kind == "BallBounced" then
					magnitude = event.magnitude or 0
				end
			end
			T.expect(magnitude):toBeNear(60, 1e-3)
		end)
	end)
end)

return true
