-- Name: OnboardingLayout.spec.luau
-- Author: Jack C.
-- Description: Spec for the tutorial arena's geometry, pinned to the real authored marker positions: that the approach axis is derived from the spawn, that distances place points where the map actually has ground, and that the bridge is correctly carved out of the elimination ring.
-- Created: 2026-08-26

--!strict

local T = require(script.Parent.TestKit)
local OnboardingLayout = require(script.Parent.Parent.Game.Onboarding.OnboardingLayout)

-- The authored markers inside Assets.Rigs.TutorialArena.
local MAP_ORIGIN = vector.create(-167.9, -67.3, -733.5)
local PLAYER_SPAWN = vector.create(-4.3, -94.5, -733.5)
local SURFACE_OFFSET = -30.5

-- Radii measured off the authored meshes: the inner island ends at ~82.5, the
-- pink ring runs out to ~127.6, and the bridge deck is ~26 studs wide.
local INNER = 84
local OUTER = 118
local HALF_WIDTH = 16

local frame = OnboardingLayout.frame(MAP_ORIGIN, PLAYER_SPAWN, SURFACE_OFFSET)

local function at(distance: number, lateral: number)
	return OnboardingLayout.point(frame, distance, lateral)
end

T.describe("OnboardingLayout", function()
	T.describe("frame", function()
		T.it("points the approach axis from the arena centre toward the spawn", function()
			T.expect(frame.forward.x):toBeNear(1, 1e-4)
			T.expect(frame.forward.y):toBeNear(0, 1e-4)
			T.expect(frame.forward.z):toBeNear(0, 1e-4)
		end)

		T.it("puts the walking surface below the marker, which sits up inside the tower", function()
			T.expect(frame.surfaceY):toBeNear(-97.8, 1e-4)
		end)

		T.it("keeps a right axis perpendicular to the approach", function()
			T.expect(vector.dot(frame.right, frame.forward)):toBeNear(0, 1e-5)
			T.expect(vector.magnitude(frame.right)):toBeNear(1, 1e-5)
		end)

		T.it("falls back to a usable axis when the spawn sits over the centre", function()
			local degenerate = OnboardingLayout.frame(MAP_ORIGIN, MAP_ORIGIN + vector.create(0, 40, 0), SURFACE_OFFSET)
			T.expect(vector.magnitude(degenerate.forward)):toBeNear(1, 1e-5)
		end)
	end)

	T.describe("placement", function()
		T.it("places the bridge waypoint at the island end of the crossing", function()
			local point = at(82, 0)
			T.expect(point.x):toBeNear(-85.9, 1e-3)
			T.expect(point.z):toBeNear(-733.5, 1e-3)
			T.expect(point.y):toBeNear(-97.8, 1e-3)
		end)

		T.it("measures the spawn back at its authored distance from the centre", function()
			T.expect(OnboardingLayout.distanceFromCentre(frame, PLAYER_SPAWN)):toBeNear(163.6, 1e-3)
		end)

		T.it("puts every ring position on the walking surface", function()
			for index = 1, 4 do
				T.expect(OnboardingLayout.ringPoint(frame, 38, index, 4).y):toBeNear(frame.surfaceY, 1e-4)
			end
		end)

		T.it("spreads ring positions around the centre rather than stacking them", function()
			local first = OnboardingLayout.ringPoint(frame, 38, 1, 4)
			local third = OnboardingLayout.ringPoint(frame, 38, 3, 4)
			T.expect(vector.magnitude(first - third)):toBeNear(76, 1e-3)
		end)

		T.it("reports no lateral offset for a point on the approach axis", function()
			T.expect(OnboardingLayout.lateralOffset(frame, at(70, 0))):toBeNear(0, 1e-4)
			T.expect(OnboardingLayout.lateralOffset(frame, at(70, 25))):toBeNear(25, 1e-4)
		end)
	end)

	T.describe("bridge", function()
		T.it("counts a player walking the deck as on the bridge", function()
			T.expect(OnboardingLayout.onBridge(frame, at(100, 0), 82, 128, HALF_WIDTH)):toEqual(true)
		end)

		T.it("does not count a player who stepped off the side", function()
			T.expect(OnboardingLayout.onBridge(frame, at(100, 30), 82, 128, HALF_WIDTH)):toEqual(false)
		end)

		T.it("does not count the island or the far outer rim", function()
			T.expect(OnboardingLayout.onBridge(frame, at(60, 0), 82, 128, HALF_WIDTH)):toEqual(false)
			T.expect(OnboardingLayout.onBridge(frame, at(140, 0), 82, 128, HALF_WIDTH)):toEqual(false)
		end)

		T.it("treats the second authored bridge on the opposite side the same way", function()
			T.expect(OnboardingLayout.onBridge(frame, at(-100, 0), 82, 128, HALF_WIDTH)):toEqual(true)
		end)
	end)

	T.describe("elimination ring", function()
		T.it("catches a player out over the pink", function()
			T.expect(OnboardingLayout.overEliminationRing(frame, at(100, 40), INNER, OUTER, HALF_WIDTH)):toEqual(true)
		end)

		T.it("never catches a player crossing on a bridge", function()
			T.expect(OnboardingLayout.overEliminationRing(frame, at(100, 0), INNER, OUTER, HALF_WIDTH)):toEqual(false)
			T.expect(OnboardingLayout.overEliminationRing(frame, at(-100, 8), INNER, OUTER, HALF_WIDTH)):toEqual(false)
		end)

		T.it("never catches a player safe on the inner island", function()
			T.expect(OnboardingLayout.overEliminationRing(frame, at(40, 40), INNER, OUTER, HALF_WIDTH)):toEqual(false)
		end)

		T.it("never catches a player back on the spawn podium", function()
			T.expect(OnboardingLayout.overEliminationRing(frame, PLAYER_SPAWN, INNER, OUTER, HALF_WIDTH)):toEqual(false)
		end)
	end)
end)

return true
