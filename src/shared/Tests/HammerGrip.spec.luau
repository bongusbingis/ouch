-- Description: Spec for the hammer grip solver: upright grips for each dominant mesh axis and rejection of ambiguous dimensions.

--!strict

local T = require(script.Parent.TestKit)
local HammerGrip = require(script.Parent.Parent.Game.Cosmetics.HammerGrip)

T.describe("HammerGrip", function()
	T.it("keeps a Y-dominant hammer upright with a proportional grip", function()
		local solution = HammerGrip.solve(1.28, 6.395, 3.156, 1.1, -0.094)
		T.expect(solution ~= nil):toBeTruthy()
		T.expect((solution :: HammerGrip.Solution).axis):toEqual("Y")
		T.expect((solution :: HammerGrip.Solution).position.y):toBeNear(-0.60113, 1e-5)
		T.expect((solution :: HammerGrip.Solution).rotationDeg.z):toEqual(0)
	end)

	T.it("rotates X and Z dominant meshes onto hand-local Y", function()
		local x = HammerGrip.solve(6, 2, 1, 1.1, 0)
		local z = HammerGrip.solve(1, 2, 6, 1.1, 0)
		T.expect((x :: HammerGrip.Solution).axis):toEqual("X")
		T.expect((x :: HammerGrip.Solution).rotationDeg.z):toEqual(-90)
		T.expect((z :: HammerGrip.Solution).axis):toEqual("Z")
		T.expect((z :: HammerGrip.Solution).rotationDeg.x):toEqual(90)
	end)

	T.it("rejects ambiguous dimensions instead of guessing a grip", function()
		T.expect(HammerGrip.solve(4, 4, 3.9, 1.1, 0)):toBeNil()
	end)
end)

return true
