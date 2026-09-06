--!strict

local TestKit = require(script.Parent.TestKit)
local SeasonClaims = require(script.Parent.Parent.UI.Models.SeasonClaims)

TestKit.describe("Season claim presentation", function()
	TestKit.it("counts only unlocked, owned, unclaimed reward tracks", function()
		local state = {
			active = true,
			hasPremium = false,
			tiers = {
				{ unlocked = true, freeReward = {}, premiumReward = {} },
				{ unlocked = true, freeReward = {}, freeClaimed = true },
				{ unlocked = false, freeReward = {}, premiumReward = {} },
			},
		}
		TestKit.expect(SeasonClaims.count(state)):toEqual(1)
		state.hasPremium = true
		TestKit.expect(SeasonClaims.count(state)):toEqual(2)
		state.active = false
		TestKit.expect(SeasonClaims.count(state)):toEqual(0)
	end)
end)

return true
