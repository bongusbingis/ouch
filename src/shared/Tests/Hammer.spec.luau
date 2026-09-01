-- Name: Hammer.spec.luau
-- Author: Jack C.
-- Description: Spec for the hammer weapon kit: routing against held balls, closest-target-in-front hits, team rules, the cooldown and recovery phases, and assisted swing turning and lunging.
-- Created: 2026-07-13

--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local Combat = require(script.Parent.Parent.Parent.Config.Gameplay.Combat)
local MobileInput = require(script.Parent.Parent.Parent.Config.Interface.MobileInput)

type InputCommand = SimTypes.InputCommand
type SimEvent = SimTypes.SimEvent

local DT = 1 / 60

local countEvents = MockWorld.countEvents

local function command(overrides: { [string]: any }?): InputCommand
	local input: InputCommand = {
		playerId = "p1",
		kind = "Throw",
		aimOrigin = vector.create(0, 2.5, 0),
		aimDir = vector.create(1, 0, 0),
		targetId = nil,
		deviceClass = "Mouse",
	}
	for key, value in overrides or {} do
		(input :: any)[key] = value
	end
	return input
end

local function world(extraCharacters: { [string]: SimTypes.CharacterSnapshot }?): SimTypes.WorldSnapshot
	local characters: { [string]: SimTypes.CharacterSnapshot } = {
		p1 = MockWorld.character(vector.create(0, 2.5, 0)),
	}
	for id, character in extraCharacters or {} do
		characters[id] = character
	end
	return MockWorld.snapshot(characters, { MockWorld.ground() }, {})
end

local function addHeldBall(state: SimTypes.SimState)
	state.projectiles.ball_0001 = {
		id = "ball_0001",
		archetype = "Dodgeball",
		ownerId = "p1",
		heldBy = "p1",
		phase = "Held",
		position = vector.create(0.9, 2.9, -0.25),
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

T.describe("Hammer kit", function()
	T.it("left click swings hammer when no dodgeball is held", function()
		local arena = world()
		local state = SimCore.newState()
		local events = SimCore.step(state, { command() }, arena, DT)

		T.expect(countEvents(events, "HammerSwing")):toEqual(1)
		T.expect(countEvents(events, "BallWindup")):toEqual(0)
	end)

	T.it("held dodgeball has priority over hammer", function()
		local arena = world()
		local state = SimCore.newState()
		SimCore.step(state, {}, arena, DT)
		addHeldBall(state)

		local events = SimCore.step(state, { command() }, arena, DT)

		T.expect(countEvents(events, "BallWindup")):toEqual(1)
		T.expect(countEvents(events, "HammerSwing")):toEqual(0)
	end)

	T.it("direct hammer hit eliminates the closest target in front", function()
		local arena = world({
			close = MockWorld.character(vector.create(4, 2.5, 0)),
			far = MockWorld.character(vector.create(6, 2.5, 0)),
		})
		local state = SimCore.newState()
		local events = SimCore.step(state, { command() }, arena, DT)

		T.expect(countEvents(events, "HammerSwing")):toEqual(1)
		T.expect(countEvents(events, "HammerHit")):toEqual(1)
		T.expect(countEvents(events, "Elim")):toEqual(1)
		for _, event in events do
			if event.kind == "HammerHit" then
				T.expect(event.targetId):toEqual("close")
			end
		end
	end)

	T.it("does not hit teammates", function()
		local arena = world({
			teammate = MockWorld.character(vector.create(4, 2.5, 0), { teamId = "Red" }),
			enemy = MockWorld.character(vector.create(6, 2.5, 0), { teamId = "Blue" }),
		})
		arena.characters.p1.teamId = "Red"
		local state = SimCore.newState()
		local events = SimCore.step(state, { command() }, arena, DT)

		T.expect(countEvents(events, "HammerHit")):toEqual(1)
		for _, event in events do
			if event.kind == "HammerHit" then
				T.expect(event.targetId):toEqual("enemy")
			end
		end
	end)

	T.it("miss enters recovery and blocks immediate repeated swings", function()
		local arena = world()
		local state = SimCore.newState()
		local first = SimCore.step(state, { command() }, arena, DT)
		T.expect(countEvents(first, "HammerSwing")):toEqual(1)

		local immediate = SimCore.step(state, { command() }, arena, DT)
		T.expect(countEvents(immediate, "HammerSwing")):toEqual(0)

		local sawMiss = false
		for _ = 1, math.ceil(Combat.Hammer.ActiveDuration / DT) + 2 do
			local events = SimCore.step(state, {}, arena, DT)
			if countEvents(events, "HammerMiss") > 0 then
				sawMiss = true
			end
		end
		T.expect(sawMiss):toBeTruthy()
		T.expect(state.players.p1.weapons.Hammer.stunRemaining > 0):toBeTruthy()

		for _ = 1, math.ceil(Combat.Hammer.MissStunDuration / DT) + 1 do
			SimCore.step(state, {}, arena, DT)
		end
		T.expect(state.players.p1.weapons.Hammer.stunRemaining):toEqual(0)
	end)

	T.it("cooldown blocks repeated swings until it fully elapses", function()
		local arena = world()
		local state = SimCore.newState()
		local first = SimCore.step(state, { command() }, arena, DT)
		T.expect(countEvents(first, "HammerSwing")):toEqual(1)

		local elapsed = DT
		while elapsed < Combat.Hammer.Cooldown - DT * 2 do
			local events = SimCore.step(state, { command() }, arena, DT)
			T.expect(countEvents(events, "HammerSwing")):toEqual(0)
			elapsed += DT
		end

		local swung = false
		for _ = 1, 6 do
			if countEvents(SimCore.step(state, { command() }, arena, DT), "HammerSwing") > 0 then
				swung = true
				break
			end
		end
		T.expect(swung):toBeTruthy()
	end)

	local function swingEvent(events: { SimEvent }): SimEvent?
		for _, event in events do
			if event.kind == "HammerSwing" then
				return event
			end
		end
		return nil
	end

	local function offAxisWorld(distance: number): SimTypes.WorldSnapshot
		local offset = distance / math.sqrt(2)
		return world({ e1 = MockWorld.character(vector.create(offset, 2.5, offset)) })
	end

	T.it("leaves the swing exactly where it was aimed with no assists", function()
		local state = SimTypes.newState()
		local events = SimCore.step(state, { command({ assist = { AutoFace = 0, Lunge = 0 } }) }, offAxisWorld(6), DT)
		local swing = swingEvent(events)
		T.expect(swing ~= nil):toBeTruthy()
		T.expect((swing :: SimEvent).direction.x):toBeNear(1, 1e-6)
		T.expect((swing :: SimEvent).direction.z):toBeNear(0, 1e-6)
	end)

	T.it("dashes at the baseline speed with no assists", function()
		local state = SimTypes.newState()
		local events = SimCore.step(state, { command({ assist = { AutoFace = 0, Lunge = 0 } }) }, offAxisWorld(6), DT)
		T.expect((swingEvent(events) :: SimEvent).magnitude):toBeNear(Combat.Hammer.DashSpeed, 1e-6)
	end)

	T.it("turns the swing toward a target that is off axis", function()
		local state = SimTypes.newState()
		local events = SimCore.step(state, { command({ assist = { AutoFace = 1 } }) }, offAxisWorld(6), DT)
		local direction = (swingEvent(events) :: SimEvent).direction
		T.expect(direction.z > 0):toBeTruthy()
		T.expect(vector.magnitude(direction)):toBeNear(1, 1e-5)
	end)

	T.it("never turns the swing further than the clamp allows", function()
		local state = SimTypes.newState()
		local events = SimCore.step(state, { command({ assist = { AutoFace = 1 } }) }, offAxisWorld(6), DT)
		local direction = (swingEvent(events) :: SimEvent).direction
		local turned = math.deg(math.acos(math.clamp(vector.dot(direction, vector.create(1, 0, 0)), -1, 1)))
		T.expect(turned <= MobileInput.Assist.AutoFaceMaxAngleDeg + 0.5):toBeTruthy()
	end)

	T.it("keeps the swing flat when the target is above the player", function()
		local state = SimTypes.newState()
		local high = world({ e1 = MockWorld.character(vector.create(4, 12, 2)) })
		local events = SimCore.step(state, { command({ assist = { AutoFace = 1 } }) }, high, DT)
		T.expect((swingEvent(events) :: SimEvent).direction.y):toBeNear(0, 1e-6)
	end)

	T.it("lunges harder at a target beyond the swing box", function()
		local state = SimTypes.newState()
		local far = world({ e1 = MockWorld.character(vector.create(Combat.Hammer.Range + 2, 2.5, 0)) })
		local events = SimCore.step(state, { command({ assist = { Lunge = 1 } }) }, far, DT)
		T.expect((swingEvent(events) :: SimEvent).magnitude > Combat.Hammer.DashSpeed):toBeTruthy()
	end)

	T.it("does not lunge at a target already inside the swing box", function()
		local state = SimTypes.newState()
		local near = world({ e1 = MockWorld.character(vector.create(Combat.Hammer.Range * 0.5, 2.5, 0)) })
		local events = SimCore.step(state, { command({ assist = { Lunge = 1 } }) }, near, DT)
		T.expect((swingEvent(events) :: SimEvent).magnitude):toBeNear(Combat.Hammer.DashSpeed, 1e-6)
	end)

	T.it("ignores teammates when assisting a swing", function()
		local state = SimTypes.newState()
		local allies = world({
			e1 = MockWorld.character(vector.create(4, 2.5, 4), { teamId = "Red" }),
		})
		allies.characters.p1.teamId = "Red"
		local events = SimCore.step(state, { command({ assist = { AutoFace = 1, Lunge = 1 } }) }, allies, DT)
		local swing = swingEvent(events) :: SimEvent
		T.expect(swing.direction.z):toBeNear(0, 1e-6)
		T.expect(swing.magnitude):toBeNear(Combat.Hammer.DashSpeed, 1e-6)
	end)

	T.it("scales the turn by strength so a half-strength assist turns less", function()
		local function turnFor(strength: number): number
			local state = SimTypes.newState()
			local events = SimCore.step(state, { command({ assist = { AutoFace = strength } }) }, offAxisWorld(6), DT)
			local direction = (swingEvent(events) :: SimEvent).direction
			return math.acos(math.clamp(vector.dot(direction, vector.create(1, 0, 0)), -1, 1))
		end
		T.expect(turnFor(0.5) < turnFor(1)):toBeTruthy()
		T.expect(turnFor(0.5) > 0):toBeTruthy()
	end)
end)

return true
