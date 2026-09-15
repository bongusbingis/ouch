-- Description: Spec for the ball preservation rule: a settled ball returns to whoever last owned it, a catch transfers ownership, and dead, departed, or already-holding owners are skipped.

--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(
	script.Parent.Parent.Parent.Parent
		:WaitForChild("ServerStorage")
		:WaitForChild("Tests")
		:WaitForChild("Helpers")
		:WaitForChild("MockWorld")
)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local ModeRegistry = require(script.Parent.Parent.Game.Modes.ModeRegistry)
local GameModes = require(script.Parent.Parent.Parent.Config.Gameplay.GameModes)
local Combat = require(script.Parent.Parent.Parent.Config.Gameplay.Combat)

local DT = 1 / 60

local function world(preserve: boolean?): SimTypes.WorldSnapshot
	local rules = if preserve == nil then nil else { preserveDodgeballs = preserve }
	return MockWorld.snapshot({
		p1 = MockWorld.character(vector.create(0, 2.5, 0)),
		p2 = MockWorld.character(vector.create(0, 2.5, 20)),
	}, { MockWorld.ground() }, nil, rules)
end

local function inFlightBall(state: SimTypes.SimState, ownerId: string)
	state.projectiles.ball_0001 = {
		id = "ball_0001",
		archetype = "Dodgeball",
		ownerId = ownerId,
		heldBy = nil,
		phase = "InFlight",
		position = vector.create(0, 6, 8),
		velocity = vector.create(0, 0, 4),
		targetId = nil,
		effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
		flightTime = Combat.Dodgeball.MaxFlightTime,
		windupRemaining = 0,
		bounceCount = 0,
		releaseAim = vector.create(0, 0, 1),
		releaseTargetId = nil,
		releaseDeviceClass = nil,
	}
end

local function settle(state: SimTypes.SimState, snapshot: SimTypes.WorldSnapshot)
	for _ = 1, 4 do
		SimCore.step(state, {}, snapshot, DT)
	end
end

T.describe("Ball preservation", function()
	T.it("returns a settled ball to its owner when the mode preserves", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "p1")
		settle(state, snapshot)

		local ball = state.projectiles.ball_0001
		T.expect(ball.phase):toEqual("Held")
		T.expect(ball.heldBy):toEqual("p1")
	end)

	T.it("leaves a settled ball in the world when the mode does not preserve", function()
		local snapshot = world(false)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "p1")
		settle(state, snapshot)

		local ball = state.projectiles.ball_0001
		T.expect(ball.phase):toEqual("Free")
		T.expect(ball.heldBy):toBeNil()
	end)

	T.it("treats absent rules as not preserving", function()
		local snapshot = world(nil)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "p1")
		settle(state, snapshot)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Free")
	end)

	T.it("re-equips the ball weapon when a preserved ball comes home", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		state.players.p1.equipped = "Hammer"
		state.players.p1.heldBallLastTick = false
		inFlightBall(state, "p1")
		settle(state, snapshot)
		T.expect(state.players.p1.equipped):toEqual("Dodgeball")
	end)

	T.it("makes a caught ball the catcher's, so it later returns to them", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)

		state.projectiles.ball_0001 = {
			id = "ball_0001",
			archetype = "Dodgeball",
			ownerId = "p2",
			heldBy = nil,
			phase = "InFlight",
			position = vector.create(0, 2.5, 4),
			velocity = vector.create(0, 0, -40),
			targetId = nil,
			effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
			flightTime = 0.1,
			windupRemaining = 0,
			bounceCount = 0,
			releaseAim = vector.create(0, 0, -1),
			releaseTargetId = nil,
			releaseDeviceClass = nil,
		}
		local catchCommand: SimTypes.InputCommand = {
			playerId = "p1",
			kind = "Catch",
			aimOrigin = vector.create(0, 2.5, 0),
			aimDir = vector.create(0, 0, 1),
		}
		local caught = false
		for _ = 1, 6 do
			for _, event in SimCore.step(state, { catchCommand }, snapshot, DT) do
				if event.kind == "BallCaught" then
					caught = true
				end
			end
			if caught then
				break
			end
		end
		T.expect(caught):toBeTruthy()
		T.expect(state.projectiles.ball_0001.ownerId):toEqual("p1")

		state.projectiles.ball_0001.phase = "InFlight"
		state.projectiles.ball_0001.heldBy = nil
		state.projectiles.ball_0001.position = vector.create(0, 6, 8)
		state.projectiles.ball_0001.velocity = vector.create(0, 0, 4)
		state.projectiles.ball_0001.flightTime = Combat.Dodgeball.MaxFlightTime
		state.projectiles.ball_0001.releaseAim = vector.create(0, 0, 1)
		settle(state, snapshot)

		T.expect(state.projectiles.ball_0001.heldBy):toEqual("p1")
	end)

	T.it("does not return a ball to a dead owner", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "p1")
		snapshot.characters.p1.alive = false
		settle(state, snapshot)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Free")
	end)

	T.it("does not return a ball to an owner who has left", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "ghost")
		settle(state, snapshot)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Free")
	end)

	T.it("does not put a second ball in a hand that already holds one", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		state.projectiles.ball_held = {
			id = "ball_held",
			archetype = "Dodgeball",
			ownerId = "p1",
			heldBy = "p1",
			phase = "Held",
			position = snapshot.characters.p1.handPosition,
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
		inFlightBall(state, "p1")
		settle(state, snapshot)

		T.expect(state.projectiles.ball_held.heldBy):toEqual("p1")
		T.expect(state.projectiles.ball_0001.phase):toEqual("Free")
	end)

	T.it("clears the spent bounce budget on a returned ball", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "p1")
		state.projectiles.ball_0001.bounceCount = Combat.Dodgeball.MaxBounces
		settle(state, snapshot)
		T.expect(state.projectiles.ball_0001.heldBy):toEqual("p1")
		T.expect(state.projectiles.ball_0001.bounceCount):toEqual(0)
	end)

	T.it("announces a return so presentation can react to it", function()
		local snapshot = world(true)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "p1")

		local returned = 0
		for _ = 1, 4 do
			for _, event in SimCore.step(state, {}, snapshot, DT) do
				if event.kind == "BallReturned" then
					returned += 1
					T.expect(event.playerId):toEqual("p1")
				end
			end
		end
		T.expect(returned):toEqual(1)
	end)

	T.it("turns the rule on for every shipped combat mode and off for a race", function()
		for _, mode in ModeRegistry.all() do
			T.expect(mode.rules.PreserveDodgeballs):toEqual(GameModes.IsCombat(mode.id))
		end
	end)
end)

return true
