--!strict

local SimTypes = require(script.Parent.Parent.Game.Sim.SimTypes)

type Vec = SimTypes.Vec
type SweepHit = SimTypes.SweepHit
type CharacterSnapshot = SimTypes.CharacterSnapshot
type WorldSnapshot = SimTypes.WorldSnapshot

-- Test-only WorldSnapshot builders: AABB static geometry with a slab-test
-- swept sphere, and simple character capsules.

export type Box = { min: Vec, max: Vec }

local MockWorld = {}

local function axisComponents(v: Vec): (number, number, number)
	return v.x, v.y, v.z
end

function MockWorld.collision(boxes: { Box }): SimTypes.CollisionWorld
	local function sweepSphere(origin: Vec, displacement: Vec, radius: number): SweepHit?
		local best: SweepHit? = nil
		local length = vector.magnitude(displacement)
		for _, box in boxes do
			-- Inflate the box by the sphere radius, then ray-vs-AABB slab test.
			local mnx, mny, mnz = axisComponents(box.min - vector.create(radius, radius, radius))
			local mxx, mxy, mxz = axisComponents(box.max + vector.create(radius, radius, radius))
			local ox, oy, oz = axisComponents(origin)
			local dx, dy, dz = axisComponents(displacement)

			local tmin, tmax = 0, 1
			local normal = vector.zero
			local miss = false

			for axis = 1, 3 do
				local o = if axis == 1 then ox elseif axis == 2 then oy else oz
				local d = if axis == 1 then dx elseif axis == 2 then dy else dz
				local mn = if axis == 1 then mnx elseif axis == 2 then mny else mnz
				local mx = if axis == 1 then mxx elseif axis == 2 then mxy else mxz

				if math.abs(d) < 1e-9 then
					if o < mn or o > mx then
						miss = true
						break
					end
				else
					local t1 = (mn - o) / d
					local t2 = (mx - o) / d
					local sign = -1
					if t1 > t2 then
						t1, t2 = t2, t1
						sign = 1
					end
					if t1 > tmin then
						tmin = t1
						normal = vector.create(
							if axis == 1 then sign else 0,
							if axis == 2 then sign else 0,
							if axis == 3 then sign else 0
						)
					end
					tmax = math.min(tmax, t2)
					if tmin > tmax then
						miss = true
						break
					end
				end
			end

			if not miss and tmin > 0 and (best == nil or tmin * length < best.distance) then
				best = {
					distance = tmin * length,
					position = origin + displacement * tmin,
					normal = normal,
				}
			end
		end
		return best
	end

	return { sweepSphere = sweepSphere }
end

function MockWorld.character(position: Vec, overrides: { [string]: any }?): CharacterSnapshot
	local character: CharacterSnapshot = {
		position = position,
		handPosition = position + vector.create(0.9, 0.4, -0.25),
		throwPosition = position + vector.create(0.6, 1.6, -0.55),
		velocity = vector.zero,
		height = 5,
		radius = 1.5,
		alive = true,
	}
	if overrides then
		for key, value in overrides do
			(character :: any)[key] = value
		end
	end
	return character
end

function MockWorld.snapshot(
	characters: { [string]: CharacterSnapshot },
	boxes: { Box }?,
	ballSpawns: { Vec }?
): WorldSnapshot
	return {
		characters = characters,
		collision = MockWorld.collision(boxes or {}),
		ballSpawns = ballSpawns or {},
	}
end

-- A large ground slab at y <= 0 so Free balls have something to settle on.
function MockWorld.ground(): Box
	return {
		min = vector.create(-1000, -10, -1000),
		max = vector.create(1000, 0, 1000),
	}
end

return MockWorld
