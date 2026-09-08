-- Description: Spec for the map feature volume test: inclusion inside the box, exclusion past any axis, surfaces counting as inside, and vertical-only padding.

--!strict

local T = require(script.Parent.TestKit)
local Volume = require(script.Parent.Parent.Game.MapFeatures.Volume)

local size = Vector3.new(10, 4, 10)

T.describe("Volume", function()
	T.it("contains an offset inside the box", function()
		T.expect(Volume.containsOffset(Vector3.new(0, 0, 0), size, 0)):toBeTruthy()
		T.expect(Volume.containsOffset(Vector3.new(4.9, 1.9, -4.9), size, 0)):toBeTruthy()
	end)

	T.it("excludes an offset past any axis", function()
		T.expect(not Volume.containsOffset(Vector3.new(5.1, 0, 0), size, 0)):toBeTruthy()
		T.expect(not Volume.containsOffset(Vector3.new(0, 0, -5.1), size, 0)):toBeTruthy()
		T.expect(not Volume.containsOffset(Vector3.new(0, 2.1, 0), size, 0)):toBeTruthy()
	end)

	T.it("treats the surface as inside", function()
		T.expect(Volume.containsOffset(Vector3.new(5, 2, 5), size, 0)):toBeTruthy()
	end)

	T.it("pads only the vertical axis", function()
		T.expect(Volume.containsOffset(Vector3.new(0, 3.9, 0), size, 2)):toBeTruthy()
		T.expect(not Volume.containsOffset(Vector3.new(0, 4.1, 0), size, 2)):toBeTruthy()
		T.expect(not Volume.containsOffset(Vector3.new(5.1, 0, 0), size, 2)):toBeTruthy()
		T.expect(not Volume.containsOffset(Vector3.new(0, 0, 5.1), size, 2)):toBeTruthy()
	end)

	T.it("pads downward as well as upward", function()
		T.expect(Volume.containsOffset(Vector3.new(0, -3.9, 0), size, 2)):toBeTruthy()
	end)
end)

return true
