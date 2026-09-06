--!strict

local T = require(script.Parent.TestKit)
local Support = require(script.Parent.Parent.Game.MapFeatures.RiderSupport)

T.describe("Airborne platform support", function()
	T.it("never acquires a ride for a player spawning or falling above a platform", function()
		T.expect(
			Support.canRetain(
				{ previous = false, sameSupport = true, airborne = true, otherContact = false, airborneSeconds = 0 },
				4
			)
		):toEqual(false)
	end)
	T.it("retains a jump only over the previously supporting assembly", function()
		local state =
			{ previous = true, sameSupport = true, airborne = true, otherContact = false, airborneSeconds = 1 }
		T.expect(Support.canRetain(state, 4)):toEqual(true)
		state.sameSupport = false
		T.expect(Support.canRetain(state, 4)):toEqual(false)
		state.sameSupport = true
		state.otherContact = true
		T.expect(Support.canRetain(state, 4)):toEqual(false)
		state.otherContact = false
		state.airborneSeconds = 5
		T.expect(Support.canRetain(state, 4)):toEqual(false)
	end)
end)

return true
