-- Name: Dodgeball.spec.luau
-- Author: Jack C.
-- Description: Spec for the dodgeball weapon kit: throw gating and cooldowns, origin validation, soft-lock cones, target leading, charge clamping, and the catch window.
-- Created: 2026-07-12

--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local Combat = require(script.Parent.Parent.Parent.Config.Gameplay.Combat)

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
		assist = { ConeSnap = 1, Lead = 0 },
	}
	for key, value in overrides or {} do
		(command :: any)[key] = value
	end
	return command
end

local function catchCommand(overrides: { [string]: any }?): InputCommand
	local command = throwCommand(overrides)
	command.kind = "Catch"
	return command
end

local function addIncomingBall(state: SimTypes.SimState, position: vector, velocity: vector)
	state.projectiles.ball_0001 = {
		id = "ball_0001",
		archetype = "Dodgeball",
		ownerId = "p2",
		heldBy = nil,
		phase = "InFlight",
		position = position,
		velocity = velocity,
		targetId = nil,
		effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
		flightTime = 0,
		windupRemaining = 0,
		bounceCount = 0,
		releaseAim = nil,
		releaseTargetId = nil,
		releaseDeviceClass = nil,
	}
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

	T.it("honors charge cancellation after an accepted action in the same tick", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand({ kind = "BeginCharge", sequence = 1 }) }, world, DT)
		SimCore.step(
			state,
			{ catchCommand({ sequence = 2 }), throwCommand({ kind = "CancelCharge", sequence = 3 }) },
			world,
			DT
		)
		T.expect(state.players.p1.weapons.Dodgeball.chargeSeconds):toBeNil()
	end)

	T.it("does not create world balls inside the pure sim", function()
		local world = arena()
		local state = SimCore.newState()
		local events = SimCore.step(state, {}, world, DT)
		T.expect(countEvents(events, "BallSpawned")):toEqual(0)
		T.expect(next(state.projectiles)):toBeNil()
	end)

	T.it("cannot catch an incoming ball across a wall", function()
		local world = MockWorld.snapshot({
			p1 = MockWorld.character(vector.create(0, 2.5, 0)),
			p2 = MockWorld.character(vector.create(10, 2.5, 0)),
		}, { { min = vector.create(2, 0, -4), max = vector.create(2.2, 8, 4) } })
		local state = SimCore.newState()
		addIncomingBall(state, vector.create(4, 2.5, 0), vector.create(-20, 0, 0))
		local events = SimCore.step(state, { catchCommand() }, world, DT)
		T.expect(countEvents(events, "BallCaught")):toEqual(0)
		T.expect(state.projectiles.ball_0001.heldBy):toBeNil()
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

	T.it("does not auto-select at all when cone snap strength is zero", function()
		local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, { throwCommand({ assist = { ConeSnap = 0 } }) }, world, DT)
		T.expect(countEvents(events, "BallWindup")):toEqual(1)
		for _, event in events do
			if event.kind == "BallWindup" then
				T.expect(event.targetId):toBeNil()
			end
		end
	end)

	T.it("still honours a tapped target when cone snap is off", function()
		local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
		local state = stateWithHeldBall(world)
		local events =
			SimCore.step(state, { throwCommand({ targetId = "dummy", assist = { ConeSnap = 0 } }) }, world, DT)
		for _, event in events do
			if event.kind == "BallWindup" then
				T.expect(event.targetId):toEqual("dummy")
			end
		end
	end)

	T.it("leaves the throw on the player's own aim when lead is off", function()
		local world = arena({
			dummy = MockWorld.character(vector.create(30, 2.5, 1), { velocity = vector.create(0, 0, 40) }),
		})
		world.characters.dummy.velocityConsistency = 1
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand({ assist = { ConeSnap = 1, Lead = 0 } }) }, world, DT)
		local ball = state.projectiles.ball_0001
		T.expect(ball.releaseAim.z):toBeNear(0, 1e-5)
	end)

	T.it("biases the throw ahead of a target moving across it", function()
		local world = arena({
			dummy = MockWorld.character(vector.create(30, 2.5, 1), { velocity = vector.create(0, 0, 40) }),
		})
		world.characters.dummy.velocityConsistency = 1
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand({ assist = { ConeSnap = 1, Lead = 1 } }) }, world, DT)
		local ball = state.projectiles.ball_0001
		T.expect(ball.releaseAim.z > 0):toBeTruthy()
	end)

	T.it("does not lead a target whose movement has been erratic", function()
		local world = arena({
			dummy = MockWorld.character(vector.create(30, 2.5, 1), { velocity = vector.create(0, 0, 40) }),
		})
		world.characters.dummy.velocityConsistency = 0
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand({ assist = { ConeSnap = 1, Lead = 1 } }) }, world, DT)
		local ball = state.projectiles.ball_0001
		T.expect(ball.releaseAim.z):toBeNear(0, 1e-5)
	end)

	T.it("carries the charge the player held through to the release", function()
		local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand({ kind = "BeginCharge" }) }, world, DT)
		for _ = 1, 32 do
			SimCore.step(state, {}, world, DT)
		end
		SimCore.step(state, { throwCommand({ charge = 0.75 }) }, world, DT)
		local ball = state.projectiles.ball_0001
		T.expect(ball.releaseCharge):toBeNear(0.75, 1e-6)
	end)

	T.it("does not trust charged releases without a server-observed hold", function()
		local world = arena({ dummy = MockWorld.character(vector.create(30, 2.5, 1)) })
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand({ charge = 12 }) }, world, DT)
		T.expect(state.projectiles.ball_0001.releaseCharge):toEqual(0)
	end)

	T.it("caps a forged full charge to elapsed simulation time", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		SimCore.step(state, { throwCommand({ kind = "BeginCharge" }) }, world, DT)
		SimCore.step(state, { throwCommand({ charge = 1 }) }, world, DT)
		T.expect(state.projectiles.ball_0001.releaseCharge):toBeNear(DT / Combat.Dodgeball.Charge.FullSeconds, 1e-6)
	end)

	T.it("cancels charge on cancellation, death, and weapon switches", function()
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
			T.expect(state.players.p1.weapons.Dodgeball.chargeSeconds):toBeNil()
		end
	end)

	T.it("keeps legacy tap throws uncharged and playable", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, { throwCommand() }, world, DT)
		T.expect(state.projectiles.ball_0001.releaseCharge):toEqual(0)
		T.expect(countEvents(events, "BallReleased")):toEqual(1)
	end)

	T.it("an invalid catch does not consume a same-tick hammer attack", function()
		local world = arena()
		local state = stateWithHeldBall(world)
		local events = SimCore.step(state, {
			throwCommand({ kind = "Equip", weapon = "Hammer" }),
			catchCommand(),
			throwCommand(),
		}, world, DT)
		T.expect(countEvents(events, "CatchStarted")):toEqual(0)
		T.expect(state.players.p1.weapons.Hammer.cooldown > 0):toBeTruthy()
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

	T.it("catches an incoming opponent ball during the explicit catch window", function()
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

		T.expect(countEvents(events, "CatchStarted")):toEqual(1)
		T.expect(countEvents(events, "BallCaught")):toEqual(1)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Held")
		T.expect(state.projectiles.ball_0001.heldBy):toEqual("p1")
	end)

	T.it("accepts only one handled action per player in a simulation tick", function()
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
		T.expect(countEvents(events, "BallCaught")):toEqual(1)
		T.expect(countEvents(events, "BallWindup")):toEqual(0)
		T.expect(countEvents(events, "HammerSwing")):toEqual(0)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Held")
	end)

	T.it("catches a fast ball crossing the catch volume within the current tick", function()
		local world = arena()
		local state = SimCore.newState()
		addIncomingBall(state, vector.create(5, 2.5, 0), vector.create(-200, 0, 0))

		local events = SimCore.step(state, { catchCommand() }, world, DT)

		T.expect(countEvents(events, "BallCaught")):toEqual(1)
		T.expect(countEvents(events, "Elim")):toEqual(0)
	end)

	T.it("does not catch a fast ball through static geometry", function()
		local baseWorld = arena()
		local world = MockWorld.snapshot(baseWorld.characters, {
			MockWorld.ground(),
			{ min = vector.create(3.6, 0, -3), max = vector.create(3.8, 6, 3) },
		}, baseWorld.ballSpawns)
		local state = SimCore.newState()
		addIncomingBall(state, vector.create(5, 2.5, 0), vector.create(-200, 0, 0))

		local events = SimCore.step(state, { catchCommand() }, world, DT)

		T.expect(countEvents(events, "BallCaught")):toEqual(0)
	end)

	T.it("keeps the catch window active until an incoming ball enters range", function()
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
		T.expect(countEvents(first, "BallCaught")):toEqual(0)
		local caught = false
		for _ = 1, math.ceil(Combat.Dodgeball.CatchWindow / DT) do
			local events = SimCore.step(state, {}, world, DT)
			if countEvents(events, "BallCaught") > 0 then
				caught = true
				break
			end
		end
		T.expect(caught):toBeTruthy()
	end)

	T.it("rejects catches outside the aim cone and on the same team", function()
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
		T.expect(countEvents(teammateEvents, "BallCaught")):toEqual(0)
		world.characters.p2.teamId = "Blue"
		state.players.p1.weapons.Dodgeball.catchCooldown = 0
		state.players.p1.weapons.Dodgeball.catchRemaining = 0
		local awayEvents = SimCore.step(state, { catchCommand({ aimDir = vector.create(-1, 0, 0) }) }, world, DT)
		T.expect(countEvents(awayEvents, "BallCaught")):toEqual(0)
	end)
end)

return true
