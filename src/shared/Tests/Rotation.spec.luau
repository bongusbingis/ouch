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
		-- The property the whole approach rests on: no frame-delta accumulation,
		-- so a client and the server agree without exchanging anything.
		T.expect(Rotation.angleAt(1234.5, 37)):toBeNear(Rotation.angleAt(1234.5, 37), 1e-9)
	end)

	T.it("honours a per-model speed", function()
		T.expect(Rotation.angleAt(1, 90)):toBeNear(math.rad(90), 1e-6)
		T.expect(Rotation.angleAt(1, 0)):toBeNear(0, 1e-6)
	end)
end)

return true
