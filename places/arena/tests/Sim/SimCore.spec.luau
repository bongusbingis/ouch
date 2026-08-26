-- Name: SimCore.spec.luau
-- Author: Jack C.
-- Description: In-place port of the end-to-end sim spec, replaying a deterministic pickup, throw, curve, and elimination scenario and pinning command arrival-order canonicalization.
-- Created: 2026-07-16

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sim = Shared:WaitForChild("Game"):WaitForChild("Sim")

local MockWorld = require(Shared:WaitForChild("Tests"):WaitForChild("MockWorld"))
local SimCore = require(Sim:WaitForChild("SimCore"))
local BallFixture = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("BallFixture"))

local DT = 1 / 60

local function eventLine(event): string
	return `{event.tick}:{event.kind}:{event.projectileId or ""}:{event.targetId or ""}`
end

local function runScenario(): { string }
	local state = SimCore.newState()
	state.projectiles.ball_0001 = BallFixture.held("ball_0001", "p1", vector.create(0.9, 2.9, -0.25))
	local log = {}

	for tick = 1, 240 do
		local dummyZ = 4 * math.sin(tick / 30)
		local world = MockWorld.snapshot({
			p1 = MockWorld.character(vector.create(0, 2.5, 0)),
			dummy = MockWorld.character(vector.create(35, 2.5, dummyZ)),
		}, { MockWorld.ground() }, { vector.create(1, 1, 0) })

		local commands = {}
		if tick == 10 then
			table.insert(commands, {
				playerId = "p1",
				kind = "Throw",
				aimOrigin = vector.create(2, 3, 0),
				aimDir = vector.normalize(vector.create(35, 0, dummyZ)),
				targetId = "dummy",
				deviceClass = "Mouse",
			})
		end

		local events = SimCore.step(state, commands, world, DT)
		for _, event in events do
			table.insert(log, eventLine(event))
		end
	end
	return log
end

local function runTwoThrowers(reversed: boolean): { string }
	local state = SimCore.newState()
	state.projectiles.ball_0001 = BallFixture.held("ball_0001", "p1", vector.create(0.9, 2.9, -0.25))
	state.projectiles.ball_0002 = BallFixture.held("ball_0002", "p2", vector.create(0.9, 2.9, 7.75))
	local log = {}

	for tick = 1, 180 do
		local world = MockWorld.snapshot({
			p1 = MockWorld.character(vector.create(0, 2.5, 0)),
			p2 = MockWorld.character(vector.create(0, 2.5, 8)),
			dummyA = MockWorld.character(vector.create(35, 2.5, 0)),
			dummyB = MockWorld.character(vector.create(35, 2.5, 8)),
		}, { MockWorld.ground() }, {})

		local commands = {}
		if tick == 10 then
			local p1Throw = {
				playerId = "p1",
				kind = "Throw",
				aimOrigin = vector.create(1, 3, 0),
				aimDir = vector.create(1, 0, 0),
				targetId = "dummyA",
				deviceClass = "Mouse",
			}
			local p2Throw = {
				playerId = "p2",
				kind = "Throw",
				aimOrigin = vector.create(1, 3, 8),
				aimDir = vector.create(1, 0, 0),
				targetId = "dummyB",
				deviceClass = "Mouse",
			}
			if reversed then
				commands = { p2Throw, p1Throw }
			else
				commands = { p1Throw, p2Throw }
			end
		end

		local events = SimCore.step(state, commands, world, DT)
		for _, event in events do
			table.insert(log, eventLine(event))
		end
	end
	return log
end

return function()
	describe("SimCore end-to-end", function()
		it("throw at a strafing dummy produces an elimination", function()
			local log = runScenario()
			local sawElim = false
			for _, line in log do
				if string.match(line, ":Elim:") then
					sawElim = true
					expect(string.match(line, "dummy$")).to.be.ok()
				end
			end
			expect(sawElim).to.equal(true)
		end)

		it("replays bit-identically", function()
			local logA = runScenario()
			local logB = runScenario()
			expect(#logA).to.equal(#logB)
			for index, line in logA do
				expect(line).to.equal(logB[index])
			end
		end)

		it("produces identical results regardless of command arrival order", function()
			local logA = runTwoThrowers(false)
			local logB = runTwoThrowers(true)
			expect(#logA > 0).to.equal(true)
			expect(#logA).to.equal(#logB)
			for index, line in logA do
				expect(line).to.equal(logB[index])
			end
		end)

		it("removes players that leave and frees their held ball", function()
			local worldWith = MockWorld.snapshot({
				p1 = MockWorld.character(vector.create(0, 2.5, 0)),
			}, { MockWorld.ground() }, { vector.create(1, 1, 0) })
			local state = SimCore.newState()
			for _ = 1, 5 do
				SimCore.step(state, {}, worldWith, DT)
			end
			state.projectiles.ball_0001 = BallFixture.held("ball_0001", "p1", vector.create(0.9, 2.9, -0.25))

			local worldWithout = MockWorld.snapshot({}, { MockWorld.ground() }, { vector.create(1, 1, 0) })
			SimCore.step(state, {}, worldWithout, DT)

			expect(state.players.p1).never.to.be.ok()
			for _, projectile in state.projectiles do
				expect(projectile.phase).to.equal("Free")
			end
		end)
	end)
end
