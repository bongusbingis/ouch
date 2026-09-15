-- Description: Spec that the rotation schedule derives its angle from the clock alone, wraps a full turn, agrees across machines, and honours a per-model speed.

--!strict

local T = require(script.Parent.TestKit)
local Rotation = require(script.Parent.Parent.Game.MapFeatures.Rotation)

T.describe("Rotation", function()
	T.it("derives the angle from the clock alone", function()
		T.expect(Rotation.angleAt(0, 20)):toBeNear(0, 1e-6)
		T.expect(Rotation.angleAt(4.5, 20)):toBeNear(math.rad(90), 1e-6)
		T.expect(Rotation.angleAt(9, 20)):toBeNear(math.rad(180), 1e-6)
	end)

	T.it("wraps a full turn instead of growing without bound", function()
		T.expect(Rotation.angleAt(18, 20)):toBeNear(0, 1e-6)
		T.expect(Rotation.angleAt(22.5, 20)):toBeNear(math.rad(90), 1e-6)
	end)

	T.it("gives two machines the same pose for the same instant", function()
		T.expect(Rotation.angleAt(1234.5, 37)):toBeNear(Rotation.angleAt(1234.5, 37), 1e-9)
	end)

	T.it("honours a per-model speed", function()
		T.expect(Rotation.angleAt(1, 90)):toBeNear(math.rad(90), 1e-6)
		T.expect(Rotation.angleAt(1, 0)):toBeNear(0, 1e-6)
	end)

	T.it("rocks about zero at phase zero and time zero", function()
		T.expect(Rotation.rockAt(0, 0.5, 4, 0)):toBeNear(0, 1e-6)
	end)

	T.it("rocks to its full amplitude a quarter period in", function()
		T.expect(Rotation.rockAt(1, 0.5, 4, 0)):toBeNear(0.5, 1e-6)
	end)

	T.it("flips sign three quarters of the way through the period", function()
		T.expect(Rotation.rockAt(3, 0.5, 4, 0)):toBeNear(-0.5, 1e-6)
	end)

	T.it("slides the same oscillation measured in studs", function()
		T.expect(Rotation.slideAt(1, 12, 4, 0)):toBeNear(12, 1e-6)
		T.expect(Rotation.slideAt(3, 12, 4, 0)):toBeNear(-12, 1e-6)
		T.expect(Rotation.slideAt(0, 12, 4, 1)):toBeNear(Rotation.rockAt(1, 12, 4, 0), 1e-9)
	end)

	T.it("reports the swing rate as the derivative of the swing", function()
		T.expect(Rotation.rockRateAt(0, 0.5, 4, 0)):toBeNear(0.5 * 2 * math.pi / 4, 1e-6)
		T.expect(Rotation.rockRateAt(1, 0.5, 4, 0)):toBeNear(0, 1e-6)
		T.expect(Rotation.rockRateAt(2, 0.5, 4, 0)):toBeNear(-0.5 * 2 * math.pi / 4, 1e-6)
		local h = 1e-4
		local numeric = (Rotation.rockAt(0.7 + h, 0.5, 4, 0.3) - Rotation.rockAt(0.7 - h, 0.5, 4, 0.3)) / (2 * h)
		T.expect(Rotation.rockRateAt(0.7, 0.5, 4, 0.3)):toBeNear(numeric, 1e-4)
	end)
end)

return true
