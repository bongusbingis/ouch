--!strict

local T = require(script.Parent.TestKit)
local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)

local SimStateCodec = require(script.Parent.Parent.Game.Adapters.SimStateCodec)
local Combat = require(script.Parent.Parent.Parent.Config.Combat)

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

	T.it("preserves hammer kit state across encode/decode", function()
		local ballsFolder = fakeInstance("Balls", "Folder")
		local character = fakeInstance("Character", "Model")
		local state = SimTypes.newState()
		state.players.p1 = {
			id = "p1",
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
