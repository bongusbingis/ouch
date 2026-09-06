-- Name: SimStateCodec.spec.luau
-- Author: Jack C.
-- Description: In-place spec running the sim state codec against real instances so attribute typing, ball CFrame storage, authored rotation, and the replication attribute limits are all exercised for real.
-- Created: 2026-07-16

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")

local SimTypes = require(Game:WaitForChild("Sim"):WaitForChild("SimTypes"))
local SimStateCodec = require(Game:WaitForChild("Adapters"):WaitForChild("SimStateCodec"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local BallFixture = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("BallFixture"))

local function makeBallsFolder(ballNames: { string }): (Folder, { [string]: BasePart })
	local folder = Instance.new("Folder")
	folder.Name = "Balls"
	local balls = {}
	for _, name in ballNames do
		local ball = Instance.new("Part")
		ball.Name = name
		ball.Anchored = true
		ball.Parent = folder
		balls[name] = ball
	end
	return folder, balls
end

return function()
	describe("SimStateCodec", function()
		local created = {}

		local function track(instance)
			table.insert(created, instance)
			return instance
		end

		afterEach(function()
			for _, instance in created do
				instance:Destroy()
			end
			table.clear(created)
		end)

		it("preserves bouncing velocity across encode/decode", function()
			local folder = track(makeBallsFolder({ "ball_0001" }))

			local state = SimTypes.newState()
			state.projectiles.ball_0001 = BallFixture.make({
				phase = "Bouncing",
				position = vector.create(12, 3, 4),
				velocity = vector.create(-80, -5, 12),
				flightTime = 0.25,
				bounceCount = 1,
			})

			SimStateCodec.encode(state, folder, {})
			local decoded = SimStateCodec.decode(folder, {})
			local decodedBall = decoded.projectiles.ball_0001

			expect(decodedBall.phase).to.equal("Bouncing")
			expect(decodedBall.velocity).to.equal(vector.create(-80, -5, 12))
			expect(decodedBall.bounceCount).to.equal(1)
			expect(decodedBall.flightTime).to.be.near(0.25)
		end)

		it("stores ball position in the part CFrame, not an attribute", function()
			local folder, balls = makeBallsFolder({ "ball_0001" })
			track(folder)

			local state = SimTypes.newState()
			state.projectiles.ball_0001 = BallFixture.make({
				phase = "InFlight",
				position = vector.create(7, 11, -3),
				velocity = vector.create(10, 0, 0),
			})

			SimStateCodec.encode(state, folder, {})

			local ball = balls.ball_0001
			expect((ball.CFrame.Position - Vector3.new(7, 11, -3)).Magnitude).to.be.near(0, 1e-4)
			for name in ball:GetAttributes() do
				expect(name == "pos" or name == "position").to.equal(false)
			end

			local decoded = SimStateCodec.decode(folder, {})
			expect(vector.magnitude(decoded.projectiles.ball_0001.position - vector.create(7, 11, -3))).to.be.near(
				0,
				1e-4
			)
		end)

		it("applies authored rotation without simulation-owned cosmetic spin", function()
			local folder, balls = makeBallsFolder({ "ball_0001" })
			track(folder)
			local ball = balls.ball_0001
			local authored = CFrame.Angles(0, math.rad(90), 0)
			ball:SetAttribute("ar", authored)

			local state = SimTypes.newState()
			state.projectiles.ball_0001 = BallFixture.make({
				phase = "InFlight",
				position = vector.create(5, 5, 5),
				velocity = vector.create(10, 0, 0),
			})

			SimStateCodec.encode(state, folder, {})

			local expected = CFrame.new(5, 5, 5) * authored
			local delta = ball.CFrame:ToObjectSpace(expected)
			expect(delta.Position.Magnitude).to.be.near(0, 1e-4)
			local axisAngle = select(2, delta:ToAxisAngle())
			expect(axisAngle).to.be.near(0, 1e-4)
		end)

		it("zeroes the replicated velocity for non-moving phases", function()
			local folder, balls = makeBallsFolder({ "ball_0001" })
			track(folder)

			local state = SimTypes.newState()
			state.projectiles.ball_0001 = BallFixture.make({
				phase = "Held",
				heldBy = "p1",
				ownerId = "p1",
				position = vector.create(0, 3, 0),
				velocity = vector.create(50, 50, 50),
			})

			SimStateCodec.encode(state, folder, {})
			expect(balls.ball_0001:GetAttribute("vel")).to.equal(vector.zero)
		end)

		it("preserves charge and hammer kit state across encode/decode", function()
			local folder = track(makeBallsFolder({}))
			local character = track(Instance.new("Model"))
			character.Name = "Character"

			local state = SimTypes.newState()
			state.players.p1 = {
				id = "p1",
				weapons = {
					Dodgeball = {
						throwCooldown = 0,
						chargeSeconds = 0.35,
						catchCooldown = 0,
						catchRemaining = 0,
						catchDirection = nil,
					},
					Hammer = {
						cooldown = 0.4,
						activeRemaining = 0.08,
						recoveryRemaining = 0,
						direction = vector.create(1, 0, 0),
						hitTargetId = "p2",
					},
				},
			}

			SimStateCodec.encode(state, folder, { p1 = character })
			local decoded = SimStateCodec.decode(folder, { p1 = character })
			expect(decoded.players.p1.weapons.Dodgeball.chargeSeconds).to.be.near(0.35)
			local hammer = decoded.players.p1.weapons.Hammer

			expect(hammer.cooldown).to.be.near(0.4)
			expect(hammer.activeRemaining).to.be.near(0.08)
			expect(hammer.direction).to.equal(vector.create(1, 0, 0))
			expect(hammer.hitTargetId).to.equal("p2")
		end)

		it("decodes a fresh part to safe defaults", function()
			local folder, _ = makeBallsFolder({ "ball_0009" })
			track(folder)

			local decoded = SimStateCodec.decode(folder, {})
			local ball = decoded.projectiles.ball_0009

			expect(ball.phase).to.equal("Free")
			expect(ball.velocity).to.equal(vector.zero)
			expect(ball.effectiveRadius).to.be.near(Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness)
			expect(ball.bounceCount).to.equal(0)
		end)

		it("stays within the replication attribute limits", function()
			local folder, balls = makeBallsFolder({ "ball_0001" })
			track(folder)
			local character = track(Instance.new("Model"))

			local state = SimTypes.newState()
			state.projectiles.ball_0001 = BallFixture.make({
				phase = "InFlight",
				ownerId = "p1",
				position = vector.create(1, 2, 3),
				velocity = vector.create(4, 5, 6),
				targetId = "p2",
				releaseAim = vector.create(1, 0, 0),
				releaseTargetId = "p2",
				releaseDeviceClass = "Mouse",
			})
			state.players.p1 = {
				id = "p1",
				weapons = {
					Dodgeball = { throwCooldown = 1, catchCooldown = 1, catchRemaining = 0, catchDirection = nil },
					Hammer = {
						cooldown = 1,
						activeRemaining = 1,
						recoveryRemaining = 1,
						direction = vector.create(1, 0, 0),
						hitTargetId = "p2",
					},
				},
			}

			SimStateCodec.encode(state, folder, { p1 = character })

			for _, instance in { folder :: Instance, balls.ball_0001 :: Instance, character :: Instance } do
				local count = 0
				for name in instance:GetAttributes() do
					count += 1
					expect(#name <= 50).to.equal(true)
				end
				expect(count <= 64).to.equal(true)
			end
		end)

		it("roundtrips tick and projectile sequence counters", function()
			local folder = track(makeBallsFolder({}))

			local state = SimTypes.newState()
			state.tick = 1234
			state.nextProjectileSeq = 7

			SimStateCodec.encode(state, folder, {})
			local decoded = SimStateCodec.decode(folder, {})

			expect(decoded.tick).to.equal(1234)
			expect(decoded.nextProjectileSeq).to.equal(7)
		end)
	end)
end
