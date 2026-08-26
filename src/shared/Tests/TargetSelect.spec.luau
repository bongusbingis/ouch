-- Name: TargetSelect.spec.luau
-- Author: Jack C.
-- Description: Spec for soft-lock selection and steering: nearest to the centre of aim, tie breaking by distance, cone and range limits, teammates and the dead ignored, confidence scoring, and clamped steering.
-- Created: 2026-08-19

--!strict

local T = require(script.Parent.TestKit)
local MockWorld = require(script.Parent.MockWorld)
local TargetSelect = require(script.Parent.Parent.Game.Sim.TargetSelect)

local ORIGIN = vector.create(0, 2.5, 0)
local FORWARD = vector.create(1, 0, 0)

local function options(overrides: { [string]: any }?): TargetSelect.Options
	local resolved: TargetSelect.Options = {
		rangeStuds = 50,
		coneDeg = 40,
		fadeStartFraction = 0.6,
		lineOfSightRadius = nil,
	}
	for key, value in overrides or {} do
		(resolved :: any)[key] = value
	end
	return resolved
end

local function worldWith(characters: { [string]: any }, parts: { any }?)
	local all: { [string]: any } = { p1 = MockWorld.character(ORIGIN) }
	for id, character in characters do
		all[id] = character
	end
	return MockWorld.snapshot(all, parts or {}, {})
end

T.describe("TargetSelect", function()
	T.it("finds nobody in an empty cone", function()
		local id, confidence = TargetSelect.pick(worldWith({}), "p1", ORIGIN, FORWARD, options())
		T.expect(id):toBeNil()
		T.expect(confidence):toEqual(0)
	end)

	T.it("picks the enemy nearest the centre of aim, not the nearest overall", function()
		local world = worldWith({
			centred = MockWorld.character(vector.create(30, 2.5, 0)),
			closeButWide = MockWorld.character(vector.create(4, 2.5, 3)),
		})
		local id = TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())
		T.expect(id):toEqual("centred")
	end)

	T.it("breaks an angular tie by distance", function()
		local world = worldWith({
			near = MockWorld.character(vector.create(10, 2.5, 0)),
			far = MockWorld.character(vector.create(30, 2.5, 0)),
		})
		T.expect(TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())):toEqual("near")
	end)

	T.it("ignores anyone outside the cone", function()
		local world = worldWith({ behind = MockWorld.character(vector.create(-20, 2.5, 0)) })
		T.expect(TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())):toBeNil()
	end)

	T.it("ignores anyone beyond the range", function()
		local world = worldWith({ distant = MockWorld.character(vector.create(80, 2.5, 0)) })
		T.expect(TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options({ rangeStuds = 50 }))):toBeNil()
	end)

	T.it("ignores teammates, the dead, and the invulnerable", function()
		local world = worldWith({
			mate = MockWorld.character(vector.create(10, 2.5, 0), { teamId = "Red" }),
			dead = MockWorld.character(vector.create(12, 2.5, 0), { alive = false }),
			safe = MockWorld.character(vector.create(14, 2.5, 0), { invulnerable = true }),
		})
		world.characters.p1.teamId = "Red"
		T.expect(TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())):toBeNil()
	end)

	T.it("never picks the selector themselves", function()
		local world = worldWith({})
		T.expect(TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())):toBeNil()
	end)

	T.it("scores a dead-centre target at full confidence", function()
		local world = worldWith({ e1 = MockWorld.character(vector.create(20, 2.5, 0)) })
		local _, confidence = TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())
		T.expect(confidence):toBeNear(1, 1e-6)
	end)

	T.it("fades confidence toward the edge of the cone", function()
		local offset = math.tan(math.rad(38)) * 20
		local world = worldWith({ e1 = MockWorld.character(vector.create(20, 2.5, offset)) })
		local id, confidence = TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())
		T.expect(id):toEqual("e1")
		T.expect(confidence > 0 and confidence < 1):toBeTruthy()
	end)

	T.it("returns the same pick for the same inputs", function()
		local world = worldWith({
			a = MockWorld.character(vector.create(20, 2.5, 1)),
			b = MockWorld.character(vector.create(20, 2.5, -1)),
			c = MockWorld.character(vector.create(21, 2.5, 0)),
		})
		local first = TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())
		for _ = 1, 20 do
			T.expect(TargetSelect.pick(world, "p1", ORIGIN, FORWARD, options())):toEqual(first)
		end
	end)

	T.it("leaves a direction untouched at zero strength", function()
		local steered = TargetSelect.steer(FORWARD, ORIGIN, vector.create(10, 2.5, 10), 0, math.rad(45))
		T.expect(steered.x):toBeNear(1, 1e-6)
		T.expect(steered.z):toBeNear(0, 1e-6)
	end)

	T.it("steers toward a point and returns a unit direction", function()
		local steered = TargetSelect.steer(FORWARD, ORIGIN, vector.create(10, 2.5, 10), 1, math.rad(45))
		T.expect(steered.z > 0):toBeTruthy()
		T.expect(vector.magnitude(steered)):toBeNear(1, 1e-5)
	end)

	T.it("never steers past the clamp", function()
		local steered = TargetSelect.steer(FORWARD, ORIGIN, vector.create(0, 2.5, 10), 1, math.rad(10))
		local angle = math.deg(math.acos(math.clamp(vector.dot(steered, FORWARD), -1, 1)))
		T.expect(angle <= 10.5):toBeTruthy()
	end)

	T.it("does not steer toward a point it is already facing", function()
		local steered = TargetSelect.steer(FORWARD, ORIGIN, vector.create(10, 2.5, 0), 1, math.rad(45))
		T.expect(steered.x):toBeNear(1, 1e-6)
	end)
end)

return true
