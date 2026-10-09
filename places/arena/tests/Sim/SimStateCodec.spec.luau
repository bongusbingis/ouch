-- Description: In-place spec running the sim state codec against real instances so attribute typing, ball CFrame storage, authored rotation, and the replication attribute limits are all exercised for real.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")

local SimTypes = require(Game:WaitForChild("Sim"):WaitForChild("SimTypes"))
local SimStateCodec = require(Game:WaitForChild("Adapters"):WaitForChild("SimStateCodec"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local BallFixture = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("BallFixture"))
local MockWorld = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("MockWorld"))
local WeaponRegistry = require(Game:WaitForChild("Sim"):WaitForChild("WeaponRegistry"))
local SimCore = require(Game:WaitForChild("Sim"):WaitForChild("SimCore"))

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

-- Plain-table stand-ins for the pure-codec cases that do not need real instance replication.
type FakeInstance = {
	Name: string,
	ClassName: string,
	CFrame: any,
	_children: { FakeInstance },
	_attributes: { [string]: any },
	GetChildren: (self: FakeInstance) -> { FakeInstance },
	IsA: (self: FakeInstance, className: string) -> boolean,
	GetAttribute: (self: FakeInstance, name: string) -> any,
	SetAttribute: (self: FakeInstance, name: string, value: any) -> (),
}

local function fakeInstance(name: string, className: string): FakeInstance
	local instance = {
		Name = name,
		ClassName = className,
		CFrame = CFrame.new(),
		_children = {},
		_attributes = {},
	} :: any

	function instance:GetChildren()
		return self._children
	end

	function instance:IsA(className: string): boolean
		return self.ClassName == className
	end

	function instance:GetAttribute(name: string): any
		return self._attributes[name]
	end

	function instance:SetAttribute(name: string, value: any)
		self._attributes[name] = value
	end

	return instance :: FakeInstance
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

		it("preserves hammer cooldown across encode/decode", function()
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
			local hammer = decoded.players.p1.weapons.Hammer

			expect(hammer.cooldown).to.be.near(0.4)
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

		it("preserves the equipped weapon across encode/decode", function()
			local ballsFolder = fakeInstance("Balls", "Folder")
			local character = fakeInstance("Character", "Model")
			local state = SimTypes.newState()
			state.players.p1 = {
				id = "p1",
				equipped = "Dodgeball",
				heldBallLastTick = true,
				weapons = {
					Dodgeball = { throwCooldown = 0, catchCooldown = 0, catchRemaining = 0, catchDirection = nil },
					Hammer = {
						cooldown = 0,
						activeRemaining = 0,
						recoveryRemaining = 0,
						stunRemaining = 0,
						direction = nil,
						hitTargetId = nil,
					},
				},
			}

			SimStateCodec.encode(state, ballsFolder :: any, { p1 = character :: any })
			local decoded = SimStateCodec.decode(ballsFolder :: any, { p1 = character :: any })

			expect(decoded.players.p1.equipped).to.equal("Dodgeball")
		end)

		it("defaults an unstepped character to the registry default weapon", function()
			local ballsFolder = fakeInstance("Balls", "Folder")
			local character = fakeInstance("Character", "Model")
			local decoded = SimStateCodec.decode(ballsFolder :: any, { p1 = character :: any })
			expect(decoded.players.p1.equipped).to.equal(WeaponRegistry.defaultKind())
		end)

		it("keeps an equipped weapon across the decode-step-encode loop the adapter runs", function()
			local ballsFolder = fakeInstance("Balls", "Folder")
			local character = fakeInstance("Character", "Model")
			local models = { p1 = character :: any }
			local world = MockWorld.snapshot({ p1 = MockWorld.character(vector.create(0, 2.5, 0)) })

			local function tick(commands)
				local state = SimStateCodec.decode(ballsFolder :: any, models)
				SimCore.step(state, commands, world, 1 / 60)
				SimStateCodec.encode(state, ballsFolder :: any, models)
				return state
			end

			tick({})
			tick({ { playerId = "p1", kind = "Equip", weapon = "Dodgeball" } })
			for _ = 1, 5 do
				local state = tick({})
				expect(state.players.p1.equipped).to.equal("Dodgeball")
			end
		end)

		it("preserves cooldown kit state across encode/decode", function()
			local ballsFolder = fakeInstance("Balls", "Folder")
			local character = fakeInstance("Character", "Model")
			local state = SimTypes.newState()
			state.players.p1 = {
				id = "p1",
				equipped = "Hammer",
				heldBallLastTick = false,
				weapons = {
					Dodgeball = {
						throwCooldown = 0.2,
						catchCooldown = 0.5,
						catchRemaining = 0.1,
						catchDirection = vector.create(1, 0, 0),
					},
					Hammer = {
						cooldown = 0.4,
						activeRemaining = 0.08,
						recoveryRemaining = 0,
						stunRemaining = 0.12,
						direction = vector.create(1, 0, 0),
						hitTargetId = "p2",
					},
				},
			}

			SimStateCodec.encode(state, ballsFolder :: any, { p1 = character :: any })
			local decoded = SimStateCodec.decode(ballsFolder :: any, { p1 = character :: any })
			local hammer = decoded.players.p1.weapons.Hammer
			local dodgeball = decoded.players.p1.weapons.Dodgeball

			expect(dodgeball.throwCooldown).to.equal(0.2)
			expect(dodgeball.catchCooldown).to.equal(0.5)

			expect(hammer.cooldown).to.equal(0.4)
		end)

		it("maps phases to numbers bidirectionally", function()
			expect(SimStateCodec.phaseToNumber("Held")).to.equal(0)
			expect(SimStateCodec.phaseToNumber("Windup")).to.equal(1)
			expect(SimStateCodec.phaseToNumber("InFlight")).to.equal(2)
			expect(SimStateCodec.phaseToNumber("Bouncing")).to.equal(3)
			expect(SimStateCodec.phaseToNumber("Rolling")).to.equal(4)
			expect(SimStateCodec.phaseToNumber("Free")).to.equal(5)

			expect(SimStateCodec.numberToPhase(0)).to.equal("Held")
			expect(SimStateCodec.numberToPhase(1)).to.equal("Windup")
			expect(SimStateCodec.numberToPhase(2)).to.equal("InFlight")
			expect(SimStateCodec.numberToPhase(3)).to.equal("Bouncing")
			expect(SimStateCodec.numberToPhase(4)).to.equal("Rolling")
			expect(SimStateCodec.numberToPhase(5)).to.equal("Free")
			expect(SimStateCodec.numberToPhase(999)).to.equal("Free")
		end)

		it("decodes individual projectiles via decodeProjectile", function()
			local ball = fakeInstance("ball_0042", "BasePart")
			ball._attributes.ph = 2
			ball._attributes.ow = "player_1"
			ball._attributes.hb = nil
			ball._attributes.tg = "player_2"
			ball._attributes.vel = vector.create(10, 20, 30)

			local decoded = SimStateCodec.decodeProjectile(ball :: any)
			expect(decoded).to.be.ok()
			if decoded then
				expect(decoded.id).to.equal("ball_0042")
				expect(decoded.phase).to.equal("InFlight")
				expect(decoded.ownerId).to.equal("player_1")
				expect(decoded.targetId).to.equal("player_2")
				expect(decoded.velocity).to.equal(vector.create(10, 20, 30))
			end

			local nonPart = fakeInstance("Folder", "Folder")
			expect(SimStateCodec.decodeProjectile(nonPart :: any)).to.equal(nil)
		end)
	end)
end
