--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)

type InputCommand = SimTypes.InputCommand
type SimEvent = SimTypes.SimEvent

local DT = 1 / 60

local countEvents = MockWorld.countEvents

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

	T.it("does not auto-select teammates", function()
		local world = arena({
			teammate = MockWorld.character(vector.create(30, 2.5, 0), { teamId = "Red" }),
		})
		world.characters.p1.teamId = "Red"
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

	T.it("applies the wider Touch validation cone per device class", function()
		-- ~20 degrees off the aim ray: outside Mouse validation (16), inside Touch (24).
		local dummyPosition = vector.create(30, 2.5, 10.9)

		local function windupTarget(deviceClass: string): string?
			local world = arena({ dummy = MockWorld.character(dummyPosition) })
			local state = stateWithHeldBall(world)
			local events =
				SimCore.step(state, { throwCommand({ targetId = "dummy", deviceClass = deviceClass }) }, world, DT)
			for _, event in events do
				if event.kind == "BallWindup" then
					return event.targetId
				end
			end
			return nil
		end

		T.expect(windupTarget("Mouse")):toBeNil()
		T.expect(windupTarget("Touch")):toEqual("dummy")
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

	T.it("throw input catches an incoming opponent ball before hammer swing", function()
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
			spinAngle = 0,
			spinRate = 0,
			releaseAim = nil,
			releaseTargetId = nil,
			releaseDeviceClass = nil,
		}

		local events = SimCore.step(state, { throwCommand() }, world, DT)

		T.expect(countEvents(events, "BallCaught")):toEqual(1)
		T.expect(countEvents(events, "HammerSwing")):toEqual(0)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Held")
		T.expect(state.projectiles.ball_0001.heldBy):toEqual("p1")
		T.expect(state.projectiles.ball_0001.ownerId):toEqual("p1")
	end)

	T.it("catch uses the configured strict distance window", function()
		local world = arena()
		local state = SimCore.newState()
		state.projectiles.ball_0001 = {
			id = "ball_0001",
			archetype = "Dodgeball",
			ownerId = "p2",
			heldBy = nil,
			phase = "InFlight",
			position = vector.create(Combat.Dodgeball.CatchDistance + 0.2, 2.5, 0),
			velocity = vector.create(-1, 0, 0),
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

		local events = SimCore.step(state, { throwCommand() }, world, DT)

		T.expect(countEvents(events, "BallCaught")):toEqual(0)
		T.expect(countEvents(events, "HammerSwing")):toEqual(1)
		T.expect(state.projectiles.ball_0001.phase):toEqual("InFlight")
	end)

	T.it("cannot catch a teammate's thrown ball", function()
		local world = arena()
		world.characters.p1.teamId = "Red"
		world.characters.p2 = MockWorld.character(vector.create(10, 2.5, 0), { teamId = "Red" })
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
			spinAngle = 0,
			spinRate = 0,
			releaseAim = nil,
			releaseTargetId = nil,
			releaseDeviceClass = nil,
		}

		local events = SimCore.step(state, { throwCommand() }, world, DT)

		T.expect(countEvents(events, "BallCaught")):toEqual(0)
		T.expect(countEvents(events, "HammerSwing")):toEqual(1)
	end)
end)

return true
