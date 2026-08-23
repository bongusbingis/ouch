--!strict

-- PreserveDodgeballs decides what happens to a ball that stops moving: it goes
-- back to whoever last owned it, or it lies where it fell as a pickup.
--
-- Ownership is the entire mechanism. A catch reassigns ownerId, so a caught ball
-- is a transfer and returns to its new owner from then on -- there is no separate
-- notion of who a ball "belongs to" that could disagree with ownerId.

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local ModeRegistry = require(script.Parent.Parent.Game.Modes.ModeRegistry)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)

local DT = 1 / 60

local function world(preserve: boolean?): SimTypes.WorldSnapshot
	local rules = if preserve == nil then nil else { preserveDodgeballs = preserve }
	return MockWorld.snapshot({
		p1 = MockWorld.character(vector.create(0, 2.5, 0)),
		p2 = MockWorld.character(vector.create(0, 2.5, 20)),
	}, { MockWorld.ground() }, nil, rules)
end

-- A ball already in flight and about to run out of time, which is the cheapest
-- deterministic way to reach a resting state.
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
		-- A snapshot with no rules is what the adapter produces between matches,
		-- when no mode is resolved. Falling back to the pre-flag behaviour means a
		-- wiring mistake looks like the old game, not like something new.
		local snapshot = world(nil)
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		inFlightBall(state, "p1")
		settle(state, snapshot)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Free")
	end)

	T.it("re-equips the ball weapon when a preserved ball comes home", function()
		-- The return lands in an empty hand, which is a pickup, so the same
		-- auto-equip that covers being granted a ball covers this too.
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
		-- The transfer rule, end to end: p2's ball is caught by p1, and from that
		-- moment it settles back to p1 rather than to the player who threw it.
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

		-- Now send it back out and let it come to rest.
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
		-- Possession is one ball per player everywhere else in the sim; a second
		-- held ball would have no socket to sit in and no way to be thrown.
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
		-- Every other way a ball reaches a hand resets this; a return is the
		-- fourth and must not carry a spent budget into the next throw.
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

	T.it("turns the rule on for every shipped mode", function()
		for _, mode in ModeRegistry.all() do
			T.expect(mode.rules.PreserveDodgeballs):toEqual(true)
		end
	end)
end)

return true
