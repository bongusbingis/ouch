-- Description: In-place port of the dodgeball weapon spec: throw gating, soft-lock selection and validation cones per device class, occlusion fail-open, and the catch window.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sim = Shared:WaitForChild("Game"):WaitForChild("Sim")

local MockWorld =
	require(game:GetService("ServerStorage"):WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("MockWorld"))
local SimCore = require(Sim:WaitForChild("SimCore"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local BallFixture = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("BallFixture"))

local DT = 1 / 60

local countEvents = MockWorld.countEvents

local function stateWithHeldBall(world)
	local state = SimCore.newState()
	SimCore.step(state, {}, world, DT)
	BallFixture.insert(state, {
		ownerId = "p1",
		heldBy = "p1",
		phase = "Held",
		position = world.characters.p1.handPosition,
	})
	return state
end

local function throwCommand(overrides)
	local command = {
		playerId = "p1",
		kind = "Throw",
		aimOrigin = vector.create(0, 2.5, 0),
		aimDir = vector.create(1, 0, 0),
		targetId = nil,
		deviceClass = "Mouse",
		assist = { ConeSnap = 1, Lead = 0 },
	}
	for key, value in overrides or {} do
		command[key] = value
	end
	return command
end

local function catchCommand(overrides)
	local command = throwCommand(overrides)
	command.kind = "Catch"
	return command
end

local function arena(extraCharacters)
	local characters = {
		p1 = MockWorld.character(vector.create(0, 2.5, 0)),
	}
	for id, character in extraCharacters or {} do
		characters[id] = character
	end
	return MockWorld.snapshot(characters, { MockWorld.ground() }, { vector.create(1, 1, 0) })
end

local function addIncomingBall(state, position, velocity)
	BallFixture.insert(state, {
		ownerId = "p2",
		phase = "InFlight",
		position = position,
		velocity = velocity,
	})
end

local function windupTargetIn(events): string?
	for _, event in events do
		if event.kind == "BallWindup" then
			return event.targetId
		end
	end
	return nil
end

return function()
	describe("Dodgeball kit", function()
		it("does not create world balls inside the pure sim", function()
			local world = arena()
			local state = SimCore.newState()
			local events = SimCore.step(state, {}, world, DT)
			expect(countEvents(events, "BallSpawned")).to.equal(0)
			expect(next(state.projectiles)).never.to.be.ok()
		end)

		it("throw requires a held ball", function()
			local world = arena()
			world.ballSpawns = {}
			local state = SimCore.newState()
			local events = SimCore.step(state, { throwCommand() }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(0)
		end)

		it("throws the held ball and respects the cooldown", function()
			local world = arena()
			local state = stateWithHeldBall(world)
			local first = SimCore.step(state, { throwCommand() }, world, DT)
			expect(countEvents(first, "BallWindup")).to.equal(1)

			for _, projectile in state.projectiles do
				projectile.phase = "Held"
				projectile.heldBy = "p1"
				projectile.ownerId = "p1"
			end
			local second = SimCore.step(state, { throwCommand() }, world, DT)
			expect(countEvents(second, "BallWindup")).to.equal(0)
		end)

		it("rejects throws whose origin is far from the character", function()
			local world = arena()
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand({ aimOrigin = vector.create(50, 2.5, 0) }) }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(0)
		end)

		it("auto-selects a soft-lock target inside the selection cone", function()
			local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand() }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(1)
			expect(windupTargetIn(events)).to.equal("dummy")
		end)

		it("does not auto-select outside the selection cone", function()
			local world = arena({ dummy = MockWorld.character(vector.create(0, 2.5, 30)) })
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand() }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(1)
			expect(windupTargetIn(events)).never.to.be.ok()
		end)

		it("does not auto-select teammates", function()
			local world = arena({
				teammate = MockWorld.character(vector.create(30, 2.5, 0), { teamId = "Red" }),
			})
			world.characters.p1.teamId = "Red"
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand() }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(1)
			expect(windupTargetIn(events)).never.to.be.ok()
		end)

		it("accepts a valid soft-lock target", function()
			local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand({ targetId = "dummy" }) }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(1)
			expect(windupTargetIn(events)).to.equal("dummy")
		end)

		it("fails open to unguided when the target is outside the validation cone", function()
			local world = arena({ dummy = MockWorld.character(vector.create(0, 2.5, 30)) })
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand({ targetId = "dummy" }) }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(1)
			expect(windupTargetIn(events)).never.to.be.ok()
		end)

		it("applies the wider Touch validation cone per device class", function()
			local dummyPosition = vector.create(30, 2.5, 10.9)

			local function windupTarget(deviceClass: string): string?
				local world = arena({ dummy = MockWorld.character(dummyPosition) })
				local state = stateWithHeldBall(world)
				local events =
					SimCore.step(state, { throwCommand({ targetId = "dummy", deviceClass = deviceClass }) }, world, DT)
				return windupTargetIn(events)
			end

			expect(windupTarget("Mouse")).never.to.be.ok()
			expect(windupTarget("Touch")).to.equal("dummy")
		end)

		it("fails open to unguided when the target is occluded", function()
			local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 0)) })
			local blocked = MockWorld.snapshot(world.characters, {
				MockWorld.ground(),
				{ min = vector.create(15, 0, -5), max = vector.create(16, 10, 5) },
			}, world.ballSpawns)
			local state = stateWithHeldBall(blocked)
			local events = SimCore.step(state, { throwCommand({ targetId = "dummy" }) }, blocked, DT)
			expect(countEvents(events, "BallWindup")).to.equal(1)
			expect(windupTargetIn(events)).never.to.be.ok()
		end)

		it("explicit catch input catches an incoming opponent ball", function()
			local world = arena()
			local state = SimCore.newState()
			BallFixture.insert(state, {
				ownerId = "p2",
				phase = "InFlight",
				position = vector.create(2.5, 2.5, 0),
				velocity = vector.create(-80, 0, 0),
			})

			local events = SimCore.step(state, { catchCommand() }, world, DT)

			expect(countEvents(events, "BallCaught")).to.equal(1)
			expect(state.projectiles.ball_0001.phase).to.equal("Held")
			expect(state.projectiles.ball_0001.heldBy).to.equal("p1")
			expect(state.projectiles.ball_0001.ownerId).to.equal("p1")
		end)

		it("catches a fast ball crossing the catch volume within one simulation tick", function()
			local world = arena()
			local state = SimCore.newState()
			BallFixture.insert(state, {
				ownerId = "p2",
				phase = "InFlight",
				position = vector.create(5, 2.5, 0),
				velocity = vector.create(-200, 0, 0),
			})

			local events = SimCore.step(state, { catchCommand() }, world, DT)

			expect(countEvents(events, "BallCaught")).to.equal(1)
			expect(countEvents(events, "Elim")).to.equal(0)
		end)

		it("catch uses the configured strict distance window", function()
			local world = arena()
			local state = SimCore.newState()
			BallFixture.insert(state, {
				ownerId = "p2",
				phase = "InFlight",
				position = vector.create(Combat.Dodgeball.CatchDistance + 0.2, 2.5, 0),
				velocity = vector.create(-1, 0, 0),
			})

			local events = SimCore.step(state, { catchCommand() }, world, DT)

			expect(countEvents(events, "BallCaught")).to.equal(0)
			expect(state.projectiles.ball_0001.phase).to.equal("InFlight")
		end)

		it("cannot catch a teammate's thrown ball", function()
			local world = arena()
			world.characters.p1.teamId = "Red"
			world.characters.p2 = MockWorld.character(vector.create(10, 2.5, 0), { teamId = "Red" })
			local state = SimCore.newState()
			BallFixture.insert(state, {
				ownerId = "p2",
				phase = "InFlight",
				position = vector.create(2.5, 2.5, 0),
				velocity = vector.create(-80, 0, 0),
			})

			local events = SimCore.step(state, { catchCommand() }, world, DT)

			expect(countEvents(events, "BallCaught")).to.equal(0)
		end)

		it("honors charge cancellation after an accepted action in the same tick", function()
			local world = arena()
			local state = stateWithHeldBall(world)
			SimCore.step(state, { throwCommand({ kind = "BeginCharge", sequence = 1 }) }, world, DT)
			SimCore.step(
				state,
				{ catchCommand({ sequence = 2 }), throwCommand({ kind = "CancelCharge", sequence = 3 }) },
				world,
				DT
			)
			expect(state.players.p1.weapons.Dodgeball.chargeSeconds).to.equal(nil)
		end)

		it("cannot catch an incoming ball across a wall", function()
			local world = MockWorld.snapshot({
				p1 = MockWorld.character(vector.create(0, 2.5, 0)),
				p2 = MockWorld.character(vector.create(10, 2.5, 0)),
			}, { { min = vector.create(2, 0, -4), max = vector.create(2.2, 8, 4) } })
			local state = SimCore.newState()
			addIncomingBall(state, vector.create(4, 2.5, 0), vector.create(-20, 0, 0))
			local events = SimCore.step(state, { catchCommand() }, world, DT)
			expect(countEvents(events, "BallCaught")).to.equal(0)
			expect(state.projectiles.ball_0001.heldBy).to.equal(nil)
		end)

		it("does not auto-select at all when cone snap strength is zero", function()
			local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand({ assist = { ConeSnap = 0 } }) }, world, DT)
			expect(countEvents(events, "BallWindup")).to.equal(1)
			for _, event in events do
				if event.kind == "BallWindup" then
					expect(event.targetId).to.equal(nil)
				end
			end
		end)

		it("still honours a tapped target when cone snap is off", function()
			local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
			local state = stateWithHeldBall(world)
			local events =
				SimCore.step(state, { throwCommand({ targetId = "dummy", assist = { ConeSnap = 0 } }) }, world, DT)
			for _, event in events do
				if event.kind == "BallWindup" then
					expect(event.targetId).to.equal("dummy")
				end
			end
		end)

		it("leaves the throw on the player's own aim when lead is off", function()
			local world = arena({
				dummy = MockWorld.character(vector.create(30, 2.5, 1), { velocity = vector.create(0, 0, 40) }),
			})
			world.characters.dummy.velocityConsistency = 1
			local state = stateWithHeldBall(world)
			SimCore.step(state, { throwCommand({ assist = { ConeSnap = 1, Lead = 0 } }) }, world, DT)
			local ball = state.projectiles.ball_0001
			expect(ball.releaseAim.z).to.be.near(0, 1e-5)
		end)

		it("biases the throw ahead of a target moving across it", function()
			local world = arena({
				dummy = MockWorld.character(vector.create(30, 2.5, 1), { velocity = vector.create(0, 0, 40) }),
			})
			world.characters.dummy.velocityConsistency = 1
			local state = stateWithHeldBall(world)
			SimCore.step(state, { throwCommand({ assist = { ConeSnap = 1, Lead = 1 } }) }, world, DT)
			local ball = state.projectiles.ball_0001
			expect(ball.releaseAim.z > 0).to.be.ok()
		end)

		it("does not lead a target whose movement has been erratic", function()
			local world = arena({
				dummy = MockWorld.character(vector.create(30, 2.5, 1), { velocity = vector.create(0, 0, 40) }),
			})
			world.characters.dummy.velocityConsistency = 0
			local state = stateWithHeldBall(world)
			SimCore.step(state, { throwCommand({ assist = { ConeSnap = 1, Lead = 1 } }) }, world, DT)
			local ball = state.projectiles.ball_0001
			expect(ball.releaseAim.z).to.be.near(0, 1e-5)
		end)

		it("carries the charge the player held through to the release", function()
			local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
			local state = stateWithHeldBall(world)
			SimCore.step(state, { throwCommand({ kind = "BeginCharge" }) }, world, DT)
			for _ = 1, 32 do
				SimCore.step(state, {}, world, DT)
			end
			SimCore.step(state, { throwCommand({ charge = 0.75 }) }, world, DT)
			local ball = state.projectiles.ball_0001
			expect(ball.releaseCharge).to.be.near(0.75, 1e-6)
		end)

		it("does not trust charged releases without a server-observed hold", function()
			local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
			local state = stateWithHeldBall(world)
			SimCore.step(state, { throwCommand({ charge = 12 }) }, world, DT)
			expect(state.projectiles.ball_0001.releaseCharge).to.equal(0)
		end)

		it("caps a forged full charge to elapsed simulation time", function()
			local world = arena()
			local state = stateWithHeldBall(world)
			SimCore.step(state, { throwCommand({ kind = "BeginCharge" }) }, world, DT)
			SimCore.step(state, { throwCommand({ charge = 1 }) }, world, DT)
			expect(state.projectiles.ball_0001.releaseCharge).to.be.near(DT / Combat.Dodgeball.Charge.FullSeconds, 1e-6)
		end)

		it("cancels charge on cancellation, death, and weapon switches", function()
			for _, cancellation in { "CancelCharge", "Death", "Equip" } do
				local world = arena()
				local state = stateWithHeldBall(world)
				SimCore.step(state, { throwCommand({ kind = "BeginCharge" }) }, world, DT)
				local commands = {}
				if cancellation == "Death" then
					world.characters.p1.alive = false
				else
					table.insert(commands, throwCommand({ kind = cancellation, weapon = "Hammer" }))
				end
				SimCore.step(state, commands, world, DT)
				expect(state.players.p1.weapons.Dodgeball.chargeSeconds).to.equal(nil)
			end
		end)

		it("keeps legacy tap throws uncharged and playable", function()
			local world = arena()
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, { throwCommand() }, world, DT)
			expect(state.projectiles.ball_0001.releaseCharge).to.equal(0)
			expect(countEvents(events, "BallReleased")).to.equal(1)
		end)

		it("an invalid catch does not consume a same-tick hammer attack", function()
			local world = arena()
			local state = stateWithHeldBall(world)
			local events = SimCore.step(state, {
				throwCommand({ kind = "Equip", weapon = "Hammer" }),
				catchCommand(),
				throwCommand(),
			}, world, DT)
			expect(countEvents(events, "CatchStarted")).to.equal(0)
			expect(state.players.p1.weapons.Hammer.cooldown > 0).to.be.ok()
		end)

		it("catches an incoming opponent ball during the explicit catch window", function()
			local world = arena()
			local state = SimCore.newState()
			state.projectiles.ball_0001 = {
				id = "ball_0001",
				archetype = "Dodgeball",
				ownerId = "p2",
				heldBy = nil,
				phase = "InFlight",
				position = vector.create(2.5, 2.5, 0),
				velocity = vector.create(-80, 0, 0),
				targetId = nil,
				effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
				flightTime = 0,
				windupRemaining = 0,
				bounceCount = 0,
				releaseAim = nil,
				releaseTargetId = nil,
				releaseDeviceClass = nil,
			}

			local events = SimCore.step(state, { catchCommand() }, world, DT)

			expect(countEvents(events, "CatchStarted")).to.equal(1)
			expect(countEvents(events, "BallCaught")).to.equal(1)
			expect(state.projectiles.ball_0001.phase).to.equal("Held")
			expect(state.projectiles.ball_0001.heldBy).to.equal("p1")
		end)

		it("accepts only one handled action per player in a simulation tick", function()
			local world = arena()
			local state = SimCore.newState()
			state.projectiles.ball_0001 = {
				id = "ball_0001",
				archetype = "Dodgeball",
				ownerId = "p2",
				heldBy = nil,
				phase = "InFlight",
				position = vector.create(2.5, 2.5, 0),
				velocity = vector.create(-80, 0, 0),
				targetId = nil,
				effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
				flightTime = 0,
				windupRemaining = 0,
				bounceCount = 0,
				releaseAim = nil,
				releaseTargetId = nil,
				releaseDeviceClass = nil,
			}
			local events = SimCore.step(state, { throwCommand(), catchCommand() }, world, DT)
			expect(countEvents(events, "BallCaught")).to.equal(1)
			expect(countEvents(events, "BallWindup")).to.equal(0)
			expect(countEvents(events, "HammerSwing")).to.equal(0)
			expect(state.projectiles.ball_0001.phase).to.equal("Held")
		end)

		it("does not catch a fast ball through static geometry", function()
			local baseWorld = arena()
			local world = MockWorld.snapshot(baseWorld.characters, {
				MockWorld.ground(),
				{ min = vector.create(3.6, 0, -3), max = vector.create(3.8, 6, 3) },
			}, baseWorld.ballSpawns)
			local state = SimCore.newState()
			addIncomingBall(state, vector.create(5, 2.5, 0), vector.create(-200, 0, 0))

			local events = SimCore.step(state, { catchCommand() }, world, DT)

			expect(countEvents(events, "BallCaught")).to.equal(0)
		end)

		it("keeps the catch window active until an incoming ball enters range", function()
			local world = arena()
			local state = SimCore.newState()
			state.projectiles.ball_0001 = {
				id = "ball_0001",
				archetype = "Dodgeball",
				ownerId = "p2",
				heldBy = nil,
				phase = "InFlight",
				position = vector.create(Combat.Dodgeball.CatchDistance + 0.6, 2.5, 0),
				velocity = vector.create(-20, 0, 0),
				targetId = nil,
				effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
				flightTime = 0,
				windupRemaining = 0,
				bounceCount = 0,
				releaseAim = nil,
				releaseTargetId = nil,
				releaseDeviceClass = nil,
			}

			local first = SimCore.step(state, { catchCommand() }, world, DT)
			expect(countEvents(first, "BallCaught")).to.equal(0)
			local caught = false
			for _ = 1, math.ceil(Combat.Dodgeball.CatchWindow / DT) do
				local events = SimCore.step(state, {}, world, DT)
				if countEvents(events, "BallCaught") > 0 then
					caught = true
					break
				end
			end
			expect(caught).to.be.ok()
		end)

		it("rejects catches outside the aim cone and on the same team", function()
			local world = arena({ p2 = MockWorld.character(vector.create(10, 2.5, 0), { teamId = "Red" }) })
			world.characters.p1.teamId = "Red"
			local state = SimCore.newState()
			state.projectiles.ball_0001 = {
				id = "ball_0001",
				archetype = "Dodgeball",
				ownerId = "p2",
				heldBy = nil,
				phase = "InFlight",
				position = vector.create(2.5, 2.5, 0),
				velocity = vector.create(-80, 0, 0),
				targetId = nil,
				effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
				flightTime = 0,
				windupRemaining = 0,
				bounceCount = 0,
				releaseAim = nil,
				releaseTargetId = nil,
				releaseDeviceClass = nil,
			}

			local teammateEvents = SimCore.step(state, { catchCommand() }, world, DT)
			expect(countEvents(teammateEvents, "BallCaught")).to.equal(0)
			world.characters.p2.teamId = "Blue"
			state.players.p1.weapons.Dodgeball.catchCooldown = 0
			state.players.p1.weapons.Dodgeball.catchRemaining = 0
			local awayEvents = SimCore.step(state, { catchCommand({ aimDir = vector.create(-1, 0, 0) }) }, world, DT)
			expect(countEvents(awayEvents, "BallCaught")).to.equal(0)
		end)
	end)
end
