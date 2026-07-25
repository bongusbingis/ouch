--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)

type SimEvent = SimTypes.SimEvent
type InputCommand = SimTypes.InputCommand

local DT = 1 / 60

-- Full scenario: player picks up a spawned ball, throws at a strafing dummy
-- with soft-lock, ball curves and eliminates it. Replayed twice to pin
-- end-to-end determinism (same events at the same ticks).
local function runScenario(): { string }
	local state = SimCore.newState()
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
	local log: { string } = {}

	for tick = 1, 240 do
		-- Dummy strafes on Z; scripted from the tick so both runs agree.
		local dummyZ = 4 * math.sin(tick / 30)
		local world = MockWorld.snapshot({
			p1 = MockWorld.character(vector.create(0, 2.5, 0)),
			dummy = MockWorld.character(vector.create(35, 2.5, dummyZ)),
		}, { MockWorld.ground() }, { vector.create(1, 1, 0) })

		local commands: { InputCommand } = {}
		if tick == 10 then
			table.insert(commands, {
				playerId = "p1",
				kind = "Throw" :: SimTypes.CommandKind,
				aimOrigin = vector.create(2, 3, 0),
				aimDir = vector.normalize(vector.create(35, 0, dummyZ)),
				targetId = "dummy",
				deviceClass = "Mouse",
			})
		end

		local events = SimCore.step(state, commands, world, DT)
		for _, event in events do
			table.insert(log, `{event.tick}:{event.kind}:{event.projectileId or ""}:{event.targetId or ""}`)
		end
	end
	return log
end

T.describe("SimCore end-to-end", function()
	T.it("throw at a strafing dummy produces an elimination", function()
		local log = runScenario()
		local sawElim = false
		for _, line in log do
			if string.match(line, ":Elim:") then
				sawElim = true
				T.expect(string.match(line, "dummy$") ~= nil):toBeTruthy()
			end
		end
		T.expect(sawElim):toBeTruthy()
	end)

	T.it("replays bit-identically", function()
		local logA = runScenario()
		local logB = runScenario()
		T.expect(#logA):toEqual(#logB)
		for index, line in logA do
			T.expect(line):toEqual(logB[index])
		end
	end)

	T.it("removes players that leave and frees their held ball", function()
		local worldWith = MockWorld.snapshot({
			p1 = MockWorld.character(vector.create(0, 2.5, 0)),
		}, { MockWorld.ground() }, { vector.create(1, 1, 0) })
		local state = SimCore.newState()
		for _ = 1, 5 do
			SimCore.step(state, {}, worldWith, DT)
		end

		local worldWithout = MockWorld.snapshot({}, { MockWorld.ground() }, { vector.create(1, 1, 0) })
		SimCore.step(state, {}, worldWithout, DT)

		T.expect(state.players.p1):toBeNil()
		for _, projectile in state.projectiles do
			T.expect(projectile.phase):toEqual("Free")
		end
	end)
end)

return true
