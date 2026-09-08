-- Description: Spec for the simulation state codec: velocity, equipped weapon, and hammer state surviving encode and decode, and the equipped weapon surviving the full decode-step-encode loop.

--!strict

local T = require(script.Parent.TestKit)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)

local SimStateCodec = require(script.Parent.Parent.Game.Adapters.SimStateCodec)
local WeaponRegistry = require(script.Parent.Parent.Game.Sim.WeaponRegistry)
local SimCore = require(script.Parent.Parent.Game.Sim.SimCore)
local MockWorld = require(
	script.Parent.Parent.Parent.Parent
		:WaitForChild("ServerStorage")
		:WaitForChild("Tests")
		:WaitForChild("Helpers")
		:WaitForChild("MockWorld")
)
local Combat = require(script.Parent.Parent.Parent.Config.Gameplay.Combat)

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

T.describe("SimStateCodec", function()
	T.it("preserves bouncing velocity across encode/decode", function()
		local ballsFolder = fakeInstance("Balls", "Folder")
		local ball = fakeInstance("ball_0001", "BasePart")
		table.insert(ballsFolder._children, ball)

		local state = SimTypes.newState()
		state.projectiles[ball.Name] = {
			id = ball.Name,
			archetype = "Dodgeball",
			ownerId = nil,
			heldBy = nil,
			phase = "Bouncing",
			position = vector.create(12, 3, 4),
			velocity = vector.create(-80, -5, 12),
			targetId = nil,
			effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness,
			flightTime = 0.25,
			windupRemaining = 0,
			bounceCount = 1,
			releaseAim = nil,
			releaseTargetId = nil,
			releaseDeviceClass = nil,
		}

		SimStateCodec.encode(state, ballsFolder :: any, {})
		local decoded = SimStateCodec.decode(ballsFolder :: any, {})
		local decodedBall = decoded.projectiles[ball.Name]

		T.expect(decodedBall.phase):toEqual("Bouncing")
		T.expect(decodedBall.velocity):toEqual(vector.create(-80, -5, 12))
		T.expect(decodedBall.bounceCount):toEqual(1)
	end)

	T.it("preserves the equipped weapon across encode/decode", function()
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

		T.expect(decoded.players.p1.equipped):toEqual("Dodgeball")
		T.expect(decoded.players.p1.heldBallLastTick):toEqual(true)
	end)

	T.it("defaults an unstepped character to the registry default weapon", function()
		local ballsFolder = fakeInstance("Balls", "Folder")
		local character = fakeInstance("Character", "Model")
		local decoded = SimStateCodec.decode(ballsFolder :: any, { p1 = character :: any })
		T.expect(decoded.players.p1.equipped):toEqual(WeaponRegistry.defaultKind())
		T.expect(decoded.players.p1.heldBallLastTick):toEqual(false)
	end)

	T.it("keeps an equipped weapon across the decode-step-encode loop the adapter runs", function()
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
			T.expect(state.players.p1.equipped):toEqual("Dodgeball")
		end
	end)

	T.it("preserves hammer kit state across encode/decode", function()
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

		T.expect(dodgeball.throwCooldown):toEqual(0.2)
		T.expect(dodgeball.catchCooldown):toEqual(0.5)
		T.expect(dodgeball.catchRemaining):toEqual(0.1)
		T.expect(dodgeball.catchDirection):toEqual(vector.create(1, 0, 0))

		T.expect(hammer.cooldown):toEqual(0.4)
		T.expect(hammer.activeRemaining):toEqual(0.08)
		T.expect(hammer.stunRemaining):toEqual(0.12)
		T.expect(hammer.direction):toEqual(vector.create(1, 0, 0))
		T.expect(hammer.hitTargetId):toEqual("p2")
	end)
end)

return true
