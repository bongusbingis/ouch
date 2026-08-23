--!strict

-- The equipped weapon replaced a derivation. Ball possession used to decide
-- which weapon a Throw reached, in three places that had to agree; now one
-- field decides, and these pin the rules that field obeys.

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local WeaponRegistry = require(script.Parent.Parent.Game.Sim.WeaponRegistry)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)

local DT = 1 / 60

local function world(): SimTypes.WorldSnapshot
	return MockWorld.snapshot({
		p1 = MockWorld.character(vector.create(0, 2.5, 0)),
		p2 = MockWorld.character(vector.create(0, 2.5, 12)),
	}, { MockWorld.ground() })
end

local function giveBall(state: SimTypes.SimState, snapshot: SimTypes.WorldSnapshot, playerId: string)
	state.projectiles.ball_0001 = {
		id = "ball_0001",
		archetype = "Dodgeball",
		ownerId = playerId,
		heldBy = playerId,
		phase = "Held",
		position = snapshot.characters[playerId].handPosition,
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
end

local function equipCommand(weapon: string?): SimTypes.InputCommand
	return { playerId = "p1", kind = "Equip", weapon = weapon }
end

local function throwCommand(): SimTypes.InputCommand
	return {
		playerId = "p1",
		kind = "Throw",
		aimOrigin = vector.create(0, 2.5, 0),
		aimDir = vector.create(0, 0, 1),
	}
end

local function countEvents(events: { SimTypes.SimEvent }, kind: string): number
	local count = 0
	for _, event in events do
		if event.kind == kind then
			count += 1
		end
	end
	return count
end

T.describe("Weapon equip", function()
	T.it("starts every player on the registry default weapon", function()
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual(WeaponRegistry.defaultKind())
	end)

	T.it("defaults to a weapon that works with nothing in hand", function()
		-- Defaulting to the ball weapon would give every player a slot that does
		-- nothing until they find a ball.
		T.expect(WeaponRegistry.defaultKind()):toEqual("Hammer")
		T.expect(WeaponRegistry.isKind(WeaponRegistry.defaultKind())):toBeTruthy()
	end)

	T.it("switches on an equip command", function()
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		SimCore.step(state, { equipCommand("Dodgeball") }, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual("Dodgeball")
	end)

	T.it("ignores an equip naming a weapon that does not exist", function()
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		SimCore.step(state, { equipCommand("Crossbow") }, snapshot, DT)
		SimCore.step(state, { equipCommand(nil) }, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual("Hammer")
	end)

	T.it("swings the hammer while holding a ball", function()
		-- The behaviour the old derivation made impossible: holding a ball used to
		-- mean the hammer refused to swing at all.
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		giveBall(state, snapshot, "p1")
		SimCore.step(state, { equipCommand("Hammer") }, snapshot, DT)
		local events = SimCore.step(state, { throwCommand() }, snapshot, DT)
		T.expect(countEvents(events, "HammerSwing")):toEqual(1)
		T.expect(state.projectiles.ball_0001.phase):toEqual("Held")
		T.expect(state.projectiles.ball_0001.heldBy):toEqual("p1")
	end)

	T.it("throws the ball rather than swinging when the ball weapon is equipped", function()
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		giveBall(state, snapshot, "p1")
		SimCore.step(state, { equipCommand("Dodgeball") }, snapshot, DT)
		local events = SimCore.step(state, { throwCommand() }, snapshot, DT)
		T.expect(countEvents(events, "HammerSwing")):toEqual(0)
		-- Left the hand. Not pinned to a specific phase: whether the windup is
		-- still running by the end of the step is a timing detail of the throw,
		-- not the routing rule under test.
		T.expect(state.projectiles.ball_0001.heldBy):toBeNil()
	end)

	T.it("does nothing on a throw with the ball weapon equipped and an empty hand", function()
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		SimCore.step(state, { equipCommand("Dodgeball") }, snapshot, DT)
		local events = SimCore.step(state, { throwCommand() }, snapshot, DT)
		T.expect(countEvents(events, "HammerSwing")):toEqual(0)
	end)

	T.it("equips the ball weapon the moment a ball reaches the hand", function()
		-- Otherwise every match would start with players holding a ball they had
		-- to press a key before they could throw.
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual("Hammer")
		giveBall(state, snapshot, "p1")
		SimCore.step(state, {}, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual("Dodgeball")
	end)

	T.it("lets a deliberate switch on the pickup tick win over the auto-equip", function()
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		giveBall(state, snapshot, "p1")
		SimCore.step(state, { equipCommand("Hammer") }, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual("Hammer")
	end)

	T.it("does not re-equip on later ticks once the player has switched away", function()
		-- The auto-equip fires on the transition into holding a ball, not while
		-- holding one, or a manual choice would be overwritten every tick.
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		giveBall(state, snapshot, "p1")
		SimCore.step(state, {}, snapshot, DT)
		SimCore.step(state, { equipCommand("Hammer") }, snapshot, DT)
		for _ = 1, 5 do
			SimCore.step(state, {}, snapshot, DT)
		end
		T.expect(state.players.p1.equipped):toEqual("Hammer")
	end)

	T.it("spends no action budget on an equip, so equip and throw land together", function()
		-- Only one action per player resolves per tick. If equipping consumed it,
		-- a HUD tap followed immediately by an attack would swallow the attack.
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		giveBall(state, snapshot, "p1")
		local events = SimCore.step(state, { equipCommand("Hammer"), throwCommand() }, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual("Hammer")
		T.expect(countEvents(events, "HammerSwing")):toEqual(1)
	end)

	T.it("keeps catching available while the hammer is equipped", function()
		-- Catch is claimed by one weapon, so it routes regardless of the equipped
		-- one. Gating it would make a ball unobtainable for anyone holding the
		-- hammer, with no way out of that state.
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		T.expect(state.players.p1.equipped):toEqual("Hammer")

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
			local events = SimCore.step(state, { catchCommand }, snapshot, DT)
			if countEvents(events, "BallCaught") > 0 then
				caught = true
				break
			end
		end
		T.expect(caught):toBeTruthy()
	end)

	T.it("forgets a player's choice when they leave", function()
		local snapshot = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, snapshot, DT)
		SimCore.step(state, { equipCommand("Dodgeball") }, snapshot, DT)
		snapshot.characters.p1 = nil
		SimCore.step(state, {}, snapshot, DT)
		T.expect(state.players.p1):toBeNil()
	end)
end)

return true
