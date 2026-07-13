--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local Projectiles = require(script.Parent.Parent.Game.Sim.Projectiles)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)

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
		spinAngle = fields.spinAngle or 0,
		spinRate = fields.spinRate or 0,
		releaseAim = fields.releaseAim,
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
			-- Target at 90 degrees off the flight path, beyond HomingBreakAngleDeg.
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
				end
			end
			T.expect(elims):toEqual(1)
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

	T.it("recalls back to the owner and re-enters Held", function()
		local state = SimTypes.newState()
		local owner = MockWorld.character(vector.create(0, 2.5, 0))
		local world = MockWorld.snapshot({ owner = owner }, { MockWorld.ground() })
		local ball = makeBall(state, {
			phase = "Recalling",
			position = vector.create(60, 1, 0),
			ownerId = "owner",
		})
		local events: { SimTypes.SimEvent } = {}
		for _ = 1, 120 do
			Projectiles.step(state, world, DT, events)
		end
		T.expect(ball.phase):toEqual("Held")
		T.expect(ball.heldBy):toEqual("owner")
		local recalled = false
		for _, event in events do
			if event.kind == "BallRecalled" then
				recalled = true
			end
		end
		T.expect(recalled):toBeTruthy()
	end)
end)

return true
