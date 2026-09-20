--!strict

local T = require(script.Parent.TestKit)
local PartyVisibilityPolicy = require(script.Parent.Parent.UI.Models.PartyVisibilityPolicy)

T.describe("PartyVisibilityPolicy", function()
	T.it("keeps every party character visible outside Shop and Inventory", function()
		T.expect(PartyVisibilityPolicy.shouldShowCharacter(20, 10, false)):toEqual(true)
	end)

	T.it("keeps only the local character visible in Shop and Inventory", function()
		T.expect(PartyVisibilityPolicy.shouldShowCharacter(10, 10, true)):toEqual(true)
		T.expect(PartyVisibilityPolicy.shouldShowCharacter(20, 10, true)):toEqual(false)
	end)
end)

return true
