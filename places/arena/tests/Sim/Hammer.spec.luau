-- Description: In-place port of the hammer weapon spec: input routing against held balls, closest-target-in-front hits, team rules, the cooldown, active, and recovery phases, and assisted swing turning and lunging.

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
local MobileInput =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("MobileInput"))

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

		local function swingEvent(events): any
			for _, event in events do
				if event.kind == "HammerSwing" then
					return event
				end
			end
			return nil
		end

		local function offAxisWorld(distance: number)
			local offset = distance / math.sqrt(2)
			return world({ e1 = MockWorld.character(vector.create(offset, 2.5, offset)) })
		end

		it("leaves the swing exactly where it was aimed with no assists", function()
			local state = SimCore.newState()
			local events =
				SimCore.step(state, { command({ assist = { AutoFace = 0, Lunge = 0 } }) }, offAxisWorld(6), DT)
			local swing = swingEvent(events)
			expect(swing ~= nil).to.equal(true)
			expect(swing.direction.x).to.be.near(1, 1e-6)
			expect(swing.direction.z).to.be.near(0, 1e-6)
		end)

		it("dashes at the baseline speed with no assists", function()
			local state = SimCore.newState()
			local events =
				SimCore.step(state, { command({ assist = { AutoFace = 0, Lunge = 0 } }) }, offAxisWorld(6), DT)
			expect(swingEvent(events).magnitude).to.be.near(Combat.Hammer.DashSpeed, 1e-6)
		end)

		it("turns the swing toward a target that is off axis", function()
			local state = SimCore.newState()
			local events = SimCore.step(state, { command({ assist = { AutoFace = 1 } }) }, offAxisWorld(6), DT)
			local direction = swingEvent(events).direction
			expect(direction.z > 0).to.equal(true)
			expect(vector.magnitude(direction)).to.be.near(1, 1e-5)
		end)

		it("never turns the swing further than the clamp allows", function()
			local state = SimCore.newState()
			local events = SimCore.step(state, { command({ assist = { AutoFace = 1 } }) }, offAxisWorld(6), DT)
			local direction = swingEvent(events).direction
			local turned = math.deg(math.acos(math.clamp(vector.dot(direction, vector.create(1, 0, 0)), -1, 1)))
			expect(turned <= MobileInput.Assist.AutoFaceMaxAngleDeg + 0.5).to.equal(true)
		end)

		it("keeps the swing flat when the target is above the player", function()
			local state = SimCore.newState()
			local high = world({ e1 = MockWorld.character(vector.create(4, 12, 2)) })
			local events = SimCore.step(state, { command({ assist = { AutoFace = 1 } }) }, high, DT)
			expect(swingEvent(events).direction.y).to.be.near(0, 1e-6)
		end)

		it("lunges harder at a target beyond the swing box", function()
			local state = SimCore.newState()
			local far = world({ e1 = MockWorld.character(vector.create(Combat.Hammer.Range + 2, 2.5, 0)) })
			local events = SimCore.step(state, { command({ assist = { Lunge = 1 } }) }, far, DT)
			expect(swingEvent(events).magnitude > Combat.Hammer.DashSpeed).to.equal(true)
		end)

		it("does not lunge at a target already inside the swing box", function()
			local state = SimCore.newState()
			local near = world({ e1 = MockWorld.character(vector.create(Combat.Hammer.Range * 0.5, 2.5, 0)) })
			local events = SimCore.step(state, { command({ assist = { Lunge = 1 } }) }, near, DT)
			expect(swingEvent(events).magnitude).to.be.near(Combat.Hammer.DashSpeed, 1e-6)
		end)

		it("hits at the lateral edge of the swing box but not past it", function()
			local still = command({ assist = { AutoFace = 0, Lunge = 0 } })
			local edge = Combat.Hammer.Width * 0.5 + 1
			local function tryLateral(lateral: number): number
				local arena = world({ e1 = MockWorld.character(vector.create(4, 2.5, lateral), { radius = 1 }) })
				local state = SimCore.newState()
				return countEvents(SimCore.step(state, { still }, arena, DT), "HammerHit")
			end
			expect(tryLateral(edge - 0.1)).to.equal(1)
			expect(tryLateral(edge + 0.1)).to.equal(0)
		end)

		it("hits at the vertical edge of the swing box but not past it", function()
			local still = command({ assist = { AutoFace = 0, Lunge = 0 } })
			local edge = Combat.Hammer.Height * 0.5
			local function tryHeight(dy: number): number
				local arena = world({ e1 = MockWorld.character(vector.create(4, 2.5 + dy, 0), { radius = 1 }) })
				local state = SimCore.newState()
				return countEvents(SimCore.step(state, { still }, arena, DT), "HammerHit")
			end
			expect(tryHeight(edge - 0.1)).to.equal(1)
			expect(tryHeight(edge + 0.1)).to.equal(0)
		end)

		it("ignores teammates when assisting a swing", function()
			local state = SimCore.newState()
			local allies = world({
				e1 = MockWorld.character(vector.create(4, 2.5, 4), { teamId = "Red" }),
			})
			allies.characters.p1.teamId = "Red"
			local events = SimCore.step(state, { command({ assist = { AutoFace = 1, Lunge = 1 } }) }, allies, DT)
			local swing = swingEvent(events)
			expect(swing.direction.z).to.be.near(0, 1e-6)
			expect(swing.magnitude).to.be.near(Combat.Hammer.DashSpeed, 1e-6)
		end)

		it("scales the turn by strength so a half-strength assist turns less", function()
			local function turnFor(strength: number): number
				local state = SimCore.newState()
				local events =
					SimCore.step(state, { command({ assist = { AutoFace = strength } }) }, offAxisWorld(6), DT)
				local direction = swingEvent(events).direction
				return math.acos(math.clamp(vector.dot(direction, vector.create(1, 0, 0)), -1, 1))
			end
			expect(turnFor(0.5) < turnFor(1)).to.equal(true)
			expect(turnFor(0.5) > 0).to.equal(true)
		end)
	end)
end
