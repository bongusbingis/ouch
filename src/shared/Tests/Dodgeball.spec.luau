--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)

type InputCommand = SimTypes.InputCommand
type SimEvent = SimTypes.SimEvent

local DT = 1 / 60

local function countEvents(events: { SimEvent }, kind: string): number
	local count = 0
	for _, event in events do
		if event.kind == kind then
			count += 1
		end
	end
	return count
end

local function stateWithHeldBall(world: SimTypes.WorldSnapshot): SimTypes.SimState
	local state = SimCore.newState()
	SimCore.step(state, {}, world, DT)
	state.projectiles.ball_0001 = {
		id = "ball_0001",
		archetype = "Dodgeball",
		ownerId = "p1",
		heldBy = "p1",
		phase = "Held",
		position = world.characters.p1.handPosition,
		velocity = vector.zero,
		targetId = nil,
		effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
		flightTime = 0,
		windupRemaining = 0,
		bounceCount = 0,
		spinAngle = 0,
		spinRate = 0,
		releaseAim = nil,
		releaseTargetId = nil,
		releaseDeviceClass = nil,
	}
	return state
end

local function throwCommand(overrides: { [string]: any }?): InputCommand
	local command: InputCommand = {
		playerId = "p1",
		kind = "Throw",
		aimOrigin = vector.create(0, 2.5, 0),
		aimDir = vector.create(1, 0, 0),
		targetId = nil,
		deviceClass = "Mouse",
	}
	for key, value in overrides or {} do
		(command :: any)[key] = value
	end
	return command
end

T.describe("Dodgeball kit", function()
	local function arena(extraCharacters: { [string]: SimTypes.CharacterSnapshot }?)
		local characters: { [string]: SimTypes.CharacterSnapshot } = {
			p1 = MockWorld.character(vector.create(0, 2.5, 0)),
		}
		for id, character in extraCharacters or {} do
			characters[id] = character
		end
		return MockWorld.snapshot(characters, { MockWorld.ground() }, { vector.create(1, 1, 0) })
	end

	T.it("does not create world balls inside the pure sim", function()
		local world = arena()
		local state = SimCore.newState()
		local events = SimCore.step(state, {}, world, DT)
		T.expect(countEvents(events, "BallSpawned")):toEqual(0)
		T.expect(next(state.projectiles)):toBeNil()
	end)

	T.it("throw requires a held ball", function()
		local world = arena()
		world.ballSpawns = {}
		local state = SimCore.newState()
		local events = SimCore.step(state, { throwCommand() }, world, DT)
		T.expect(countEvents(events, "BallWindup")):toEqual(0)
	end)

	T.it("throws the held ball and respects the cooldown", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		local first = SimCore.step(state, { throwCommand() }, world, DT)
		T.expect(countEvents(first, "BallWindup")):toEqual(1)

		-- Immediately give the player another ball; cooldown must still block.
		for _, projectile in state.projectiles do
			projectile.phase = "Held"
			projectile.heldBy = "p1"
			projectile.ownerId = "p1"
		end
		local second = SimCore.step(state, { throwCommand() }, world, DT)
		T.expect(countEvents(second, "BallWindup")):toEqual(0)
	end)

	T.it("rejects throws whose origin is far from the character", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, { throwCommand({ aimOrigin = vector.create(50, 2.5, 0) }) }, world, DT)
		T.expect(countEvents(events, "BallWindup")):toEqual(0)
	end)

	T.it("auto-selects a soft-lock target inside the selection cone", function()
		local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, { throwCommand() }, world, DT)
		T.expect(countEvents(events, "BallWindup")):toEqual(1)
		for _, event in events do
			if event.kind == "BallWindup" then
				T.expect(event.targetId):toEqual("dummy")
			end
		end
	end)

	T.it("does not auto-select outside the selection cone", function()
		local world = arena({ dummy = MockWorld.character(vector.create(0, 2.5, 30)) })
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, { throwCommand() }, world, DT)
		for _, event in events do
			if event.kind == "BallWindup" then
				T.expect(event.targetId):toBeNil()
			end
		end
	end)

	T.it("accepts a valid soft-lock target", function()
		local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, { throwCommand({ targetId = "dummy" }) }, world, DT)
		T.expect(countEvents(events, "BallWindup")):toEqual(1)
		for _, event in events do
			if event.kind == "BallWindup" then
				T.expect(event.targetId):toEqual("dummy")
			end
		end
	end)

	T.it("fails open to unguided when the target is outside the validation cone", function()
		local world = arena({ dummy = MockWorld.character(vector.create(0, 2.5, 30)) })
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, { throwCommand({ targetId = "dummy" }) }, world, DT)
		for _, event in events do
			if event.kind == "BallWindup" then
				T.expect(event.targetId):toBeNil()
			end
		end
	end)

	T.it("fails open to unguided when the target is occluded", function()
		local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 0)) })
		local blocked = MockWorld.snapshot(world.characters, {
			MockWorld.ground(),
			{ min = vector.create(15, 0, -5), max = vector.create(16, 10, 5) },
		}, world.ballSpawns)
		local state = stateWithHeldBall(blocked)
		local events = SimCore.step(state, { throwCommand({ targetId = "dummy" }) }, blocked, DT)
		for _, event in events do
			if event.kind == "BallWindup" then
				T.expect(event.targetId):toBeNil()
			end
		end
	end)

	T.it("recall transitions an in-flight ball and respects max distance", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand() }, world, DT)
		-- Let the ball travel out of instant-repossess range before recalling.
		for _ = 1, 30 do
			SimCore.step(state, {}, world, DT)
		end

		local recallCommand: InputCommand = { playerId = "p1", kind = "Recall" }
		SimCore.step(state, { recallCommand }, world, DT)
		local recalling = 0
		for _, projectile in state.projectiles do
			if projectile.phase == "Recalling" then
				recalling += 1
			end
		end
		T.expect(recalling):toEqual(1)
	end)

	T.it("recall is rejected beyond max distance", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand() }, world, DT)
		for _ = 1, math.ceil(Combat.Dodgeball.WindupDuration / DT) + 1 do
			SimCore.step(state, {}, world, DT)
		end
		for _, projectile in state.projectiles do
			if projectile.phase == "InFlight" then
				projectile.position = vector.create(Combat.Dodgeball.RecallMaxDistance + 50, 2, 0)
			end
		end
		SimCore.step(state, { { playerId = "p1", kind = "Recall" } :: InputCommand }, world, DT)
		for _, projectile in state.projectiles do
			T.expect(projectile.phase == "Recalling"):toEqual(false)
		end
	end)
end)

return true
