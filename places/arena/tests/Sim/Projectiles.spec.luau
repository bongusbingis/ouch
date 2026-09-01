-- Name: Projectiles.spec.luau
-- Author: Jack C.
-- Description: In-place port of the projectile spec: swept kinematics, homing clamps, bounce and roll transitions, release sockets, and hit rules.
-- Created: 2026-07-16

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sim = Shared:WaitForChild("Game"):WaitForChild("Sim")

local MockWorld = require(Shared:WaitForChild("Tests"):WaitForChild("MockWorld"))
local SimTypes = require(Sim:WaitForChild("SimTypes"))
local Projectiles = require(Sim:WaitForChild("Projectiles"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local BallFixture = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("BallFixture"))

local DT = 1 / 60

local function withConfig(overrides, fn)
	local cfg = Combat.Dodgeball
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

local makeBall = BallFixture.insert

local function angleBetween(a: vector, b: vector): number
	return math.acos(math.clamp(vector.dot(vector.normalize(a), vector.normalize(b)), -1, 1))
end

return function()
	describe("Projectiles", function()
		it("flies straight and lands within max flight time", function()
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
				expect(ball.phase == "Bouncing" or ball.phase == "Free").to.equal(true)
				expect(ball.position.y).to.be.near(Combat.Dodgeball.Radius, 1e-3)
				expect(ball.position.x > 200).to.equal(true)
			end)
		end)

		it("is deterministic across identical runs", function()
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
			expect(posA == posB).to.equal(true)
			expect(eventsA).to.equal(eventsB)
		end)

		it("clamps homing turn rate per tick", function()
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
				expect(turned <= math.rad(Combat.Dodgeball.HomingTurnRateDeg) * DT + 1e-4).to.equal(true)
				expect(turned > 0).to.equal(true)
			end)
		end)

		it("breaks lock past the break angle", function()
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
				expect(angleBetween(before, ball.velocity)).to.be.near(0, 1e-5)
			end)
		end)

		it("does not tunnel through thin walls at high speed", function()
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
				expect(ball.phase == "Bouncing" or ball.phase == "Free").to.equal(true)
				expect(ball.position.x < 30).to.equal(true)
			end)
		end)

		it("rebounds away from vertical walls instead of sticking", function()
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
				local events = {}
				for _ = 1, 10 do
					Projectiles.step(state, world, DT, events)
					if ball.bounceCount > 0 then
						break
					end
				end

				expect(ball.phase).to.equal("Bouncing")
				expect(ball.bounceCount).to.equal(1)
				expect(ball.velocity.x < 0).to.equal(true)
				expect(ball.position.x < 20 - Combat.Dodgeball.Radius).to.equal(true)

				local afterBounceX = ball.position.x
				Projectiles.step(state, world, DT, events)
				expect(ball.position.x < afterBounceX).to.equal(true)
			end)
		end)

		it("preserves damped tangential wall motion on rebound", function()
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

				expect(ball.velocity.x < 0).to.equal(true)
				expect(ball.velocity.z).to.be.near(45, 1e-3)
			end)
		end)

		it("settles after the configured maximum bounce count", function()
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
				local events = {}

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

				expect(ball.phase).to.equal("Free")
				expect(ball.bounceCount).to.equal(2)
				expect(bounceEvents).to.equal(2)
				expect(settleEvents).to.equal(1)
			end)
		end)

		it("rolls after the final floor bounce before settling", function()
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
				local events = {}

				for _ = 1, 60 do
					Projectiles.step(state, world, DT, events)
					if ball.phase == "Rolling" then
						break
					end
				end

				expect(ball.phase).to.equal("Rolling")
				expect(ball.velocity.x > 0).to.equal(true)
				expect(math.abs(ball.velocity.y)).to.be.near(0, 1e-5)
				local rollingX = ball.position.x

				for _ = 1, 10 do
					Projectiles.step(state, world, DT, events)
				end
				expect(ball.position.x > rollingX).to.equal(true)

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

				expect(ball.phase).to.equal("Free")
				expect(rolled).to.equal(true)
				expect(settled).to.equal(true)
			end)
		end)

		it("clears the floor on steep downward overhand release", function()
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
				local events = {}

				Projectiles.step(state, world, DT, events)
				expect(ball.phase).to.equal("InFlight")
				expect(ball.position.y >= Combat.Dodgeball.Radius).to.equal(true)

				for _ = 1, 10 do
					Projectiles.step(state, world, DT, events)
					if ball.bounceCount > 0 then
						break
					end
				end

				expect(ball.bounceCount > 0).to.equal(true)
				expect(ball.phase == "Bouncing" or ball.phase == "Rolling").to.equal(true)
			end)
		end)

		it("holds at the fake held socket during windup", function()
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

			expect(ball.phase).to.equal("Windup")
			expect(ball.position).to.equal(owner.handPosition)
		end)

		it("releases from the overhand socket with the configured forward offset", function()
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

				expect(ball.phase).to.equal("InFlight")
				expect(ball.position).to.equal(owner.throwPosition + aim * 1.25)
			end)
		end)

		it("eliminates a character in the flight path exactly once", function()
			withConfig({ Gravity = 0 }, function()
				local state = SimTypes.newState()
				local target = MockWorld.character(vector.create(20, 3, 0))
				local world = MockWorld.snapshot({ dummy = target }, { MockWorld.ground() })
				makeBall(state, {
					position = vector.create(0, 3, 0),
					velocity = vector.create(80, 0, 0),
					ownerId = "shooter",
				})
				local events = {}
				for _ = 1, 60 do
					Projectiles.step(state, world, DT, events)
				end
				local elims = 0
				for _, event in events do
					if event.kind == "Elim" then
						elims += 1
						expect(event.targetId).to.equal("dummy")
						expect(event.sourceId).to.equal("shooter")
						expect(event.direction).to.equal(vector.create(1, 0, 0))
					end
				end
				expect(elims).to.equal(1)
			end)
		end)

		it("passes through invulnerable characters without eliminating them", function()
			withConfig({ Gravity = 0 }, function()
				local state = SimTypes.newState()
				local target = MockWorld.character(vector.create(20, 3, 0), { invulnerable = true })
				local world = MockWorld.snapshot({ dummy = target }, { MockWorld.ground() })
				makeBall(state, {
					position = vector.create(0, 3, 0),
					velocity = vector.create(80, 0, 0),
					ownerId = "shooter",
				})
				local events = {}
				for _ = 1, 60 do
					Projectiles.step(state, world, DT, events)
				end
				for _, event in events do
					expect(event.kind == "Elim").to.equal(false)
				end
			end)
		end)

		it("passes through teammates without eliminating them", function()
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
				local events = {}
				for _ = 1, 60 do
					Projectiles.step(state, world, DT, events)
				end
				for _, event in events do
					if event.kind == "Elim" then
						expect(event.targetId).to.equal("enemy")
					end
				end
			end)
		end)

		it("never hits its own thrower while in flight", function()
			withConfig({ Gravity = 0 }, function()
				local state = SimTypes.newState()
				local shooter = MockWorld.character(vector.create(0, 3, 0))
				local world = MockWorld.snapshot({ shooter = shooter }, { MockWorld.ground() })
				makeBall(state, {
					position = vector.create(0, 3, 0),
					velocity = vector.create(80, 0, 0),
					ownerId = "shooter",
				})
				local events = {}
				for _ = 1, 30 do
					Projectiles.step(state, world, DT, events)
				end
				for _, event in events do
					expect(event.kind == "Elim").to.equal(false)
				end
			end)
		end)

		it("reports impact speed on bounce events", function()
			withConfig({ Gravity = 0 }, function()
				local state = SimTypes.newState()
				local wall = { min = vector.create(5, -10, -10), max = vector.create(6, 10, 10) }
				makeBall(state, {
					position = vector.create(0, 2, 0),
					velocity = vector.create(60, 0, 0),
				})
				local events = {}
				for _ = 1, 10 do
					Projectiles.step(state, MockWorld.snapshot({}, { wall }), DT, events)
				end
				local magnitude = 0
				for _, event in events do
					if event.kind == "BallBounced" then
						magnitude = event.magnitude or 0
					end
				end
				expect(magnitude).to.be.near(60, 1e-3)
			end)
		end)
	end)
end
