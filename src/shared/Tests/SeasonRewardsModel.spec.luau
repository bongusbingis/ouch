--!strict
local T = require(script.Parent.TestKit)
local Model = require(script.Parent.Parent.UI.Models.SeasonRewardsModel)

T.describe("Season reward access", function()
	T.it("separates earning a tier from buying premium access", function()
		local state = {
			active = true,
			hasPremium = false,
			tiers = {
				{ tier = 1, unlocked = true, premiumReward = { kind = "Bonks", amount = 300 } },
				{ tier = 2, unlocked = false, freeReward = { kind = "Bonks", amount = 250 } },
			},
		}
		local entries = Model.entries(state)
		T.expect(entries[1].claimable):toEqual(false)
		T.expect(Model.requirement(entries[1])):toEqual("GET THE PREMIUM PASS TO UNLOCK")
		T.expect(Model.selected(entries, nil).tier):toEqual(2)
		state.hasPremium = true
		entries = Model.entries(state)
		T.expect(entries[1].claimable):toEqual(true)
		T.expect(entries[2].claimable):toEqual(false)
		T.expect(Model.selected(entries, nil).tier):toEqual(1)
	end)
	T.it("keeps already-claimed currency distinct from a pending cosmetic", function()
		local state = {
			active = true,
			hasPremium = true,
			tiers = {
				{
					tier = 3,
					unlocked = true,
					premiumReward = { kind = "Bonks", amount = 300 },
					premiumClaimed = true,
					premiumCosmetics = { { itemId = "Outfit", claimed = false } },
				},
			},
		}
		local entries = Model.entries(state)
		T.expect(entries[1].claimed):toEqual(true)
		T.expect(Model.selected(entries, nil).itemId):toEqual("Outfit")
		T.expect(entries[2].claimable):toEqual(true)
		state.active = false
		T.expect(Model.entries(state)[2].claimable):toEqual(false)
	end)
	T.it("retains a selected reward as its access changes", function()
		local state = {
			active = true,
			hasPremium = false,
			tiers = {
				{ tier = 4, unlocked = false, premiumReward = { kind = "Cosmetic", itemId = "Hat" } },
			},
		}
		local entry = Model.entries(state)[1]
		T.expect(Model.requirement(entry)):toEqual("PREMIUM PASS + TIER 4")
		state.hasPremium = true
		state.tiers[1].unlocked = true
		local current = Model.selected(Model.entries(state), entry.key)
		T.expect(current.itemId):toEqual("Hat")
		T.expect(current.claimable):toEqual(true)
		T.expect(Model.selected({}, nil)):toBeNil()
	end)
end)
return true
