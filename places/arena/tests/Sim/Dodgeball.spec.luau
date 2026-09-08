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
	end)
end
