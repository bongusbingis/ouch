-- Description: In-place port of the hammer weapon spec: input routing against held balls, closest-target-in-front hits, team rules, and the cooldown, active, and recovery phases.

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

local function command(overrides)
	local input = {
		playerId = "p1",
		kind = "Throw",
		aimOrigin = vector.create(0, 2.5, 0),
		aimDir = vector.create(1, 0, 0),
		targetId = nil,
		deviceClass = "Mouse",
	}
	for key, value in overrides or {} do
		input[key] = value
	end
	return input
end

local function world(extraCharacters)
	local characters = {
		p1 = MockWorld.character(vector.create(0, 2.5, 0)),
	}
	for id, character in extraCharacters or {} do
		characters[id] = character
	end
	return MockWorld.snapshot(characters, { MockWorld.ground() }, {})
end

return function()
	describe("Hammer kit", function()
		it("left click swings hammer when no dodgeball is held", function()
			local arena = world()
			local state = SimCore.newState()
			local events = SimCore.step(state, { command() }, arena, DT)

			expect(countEvents(events, "HammerSwing")).to.equal(1)
			expect(countEvents(events, "BallWindup")).to.equal(0)
		end)

		it("held dodgeball has priority over hammer", function()
			local arena = world()
			local state = SimCore.newState()
			SimCore.step(state, {}, arena, DT)
			BallFixture.insert(state, {
				ownerId = "p1",
				heldBy = "p1",
				phase = "Held",
				position = vector.create(0.9, 2.9, -0.25),
			})

			local events = SimCore.step(state, { command() }, arena, DT)

			expect(countEvents(events, "BallWindup")).to.equal(1)
			expect(countEvents(events, "HammerSwing")).to.equal(0)
		end)

		it("direct hammer hit eliminates the closest target in front", function()
			local arena = world({
				close = MockWorld.character(vector.create(4, 2.5, 0)),
				far = MockWorld.character(vector.create(6, 2.5, 0)),
			})
			local state = SimCore.newState()
			local events = SimCore.step(state, { command() }, arena, DT)

			expect(countEvents(events, "HammerSwing")).to.equal(1)
			expect(countEvents(events, "HammerHit")).to.equal(1)
			expect(countEvents(events, "Elim")).to.equal(1)
			for _, event in events do
				if event.kind == "HammerHit" then
					expect(event.targetId).to.equal("close")
				end
			end
		end)

		it("does not hit teammates", function()
			local arena = world({
				teammate = MockWorld.character(vector.create(4, 2.5, 0), { teamId = "Red" }),
				enemy = MockWorld.character(vector.create(6, 2.5, 0), { teamId = "Blue" }),
			})
			arena.characters.p1.teamId = "Red"
			local state = SimCore.newState()
			local events = SimCore.step(state, { command() }, arena, DT)

			expect(countEvents(events, "HammerHit")).to.equal(1)
			for _, event in events do
				if event.kind == "HammerHit" then
					expect(event.targetId).to.equal("enemy")
				end
			end
		end)

		it("does not hit invulnerable targets", function()
			local arena = world({
				shielded = MockWorld.character(vector.create(4, 2.5, 0), { invulnerable = true }),
			})
			local state = SimCore.newState()
			local events = SimCore.step(state, { command() }, arena, DT)

			expect(countEvents(events, "HammerSwing")).to.equal(1)
			expect(countEvents(events, "Elim")).to.equal(0)
		end)

		it("miss enters recovery and blocks immediate repeated swings", function()
			local arena = world()
			local state = SimCore.newState()
			local first = SimCore.step(state, { command() }, arena, DT)
			expect(countEvents(first, "HammerSwing")).to.equal(1)

			local immediate = SimCore.step(state, { command() }, arena, DT)
			expect(countEvents(immediate, "HammerSwing")).to.equal(0)

			local sawMiss = false
			for _ = 1, math.ceil(Combat.Hammer.ActiveDuration / DT) + 2 do
				local events = SimCore.step(state, {}, arena, DT)
				if countEvents(events, "HammerMiss") > 0 then
					sawMiss = true
				end
			end
			expect(sawMiss).to.equal(true)
		end)

		it("cooldown blocks repeated swings until it fully elapses", function()
			local arena = world()
			local state = SimCore.newState()
			local first = SimCore.step(state, { command() }, arena, DT)
			expect(countEvents(first, "HammerSwing")).to.equal(1)

			local elapsed = DT
			while elapsed < Combat.Hammer.Cooldown - DT * 2 do
				local events = SimCore.step(state, { command() }, arena, DT)
				expect(countEvents(events, "HammerSwing")).to.equal(0)
				elapsed += DT
			end

			local swung = false
			for _ = 1, 6 do
				if countEvents(SimCore.step(state, { command() }, arena, DT), "HammerSwing") > 0 then
					swung = true
					break
				end
			end
			expect(swung).to.equal(true)
		end)
	end)
end
