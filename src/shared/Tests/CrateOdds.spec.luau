--!strict

local T = require(script.Parent.TestKit)
local CrateOdds = require(script.Parent.Parent.Game.Economy.CrateOdds)

local RARITIES = {
	Common = { Weight = 70 },
	Rare = { Weight = 24 },
	Legendary = { Weight = 6 },
	Exclusive = { Weight = 0 },
}

T.describe("CrateOdds", function()
	T.it("reports every rollable outcome from the authoritative weighting model", function()
		local model = CrateOdds.build({
			ItemPool = { "CommonA", "CommonB", "RareA", "LegendaryA", "ExclusiveA" },
		}, {
			CommonA = { Rarity = "Common" },
			CommonB = { Rarity = "Common" },
			RareA = { Rarity = "Rare" },
			LegendaryA = { Rarity = "Legendary" },
			ExclusiveA = { Rarity = "Exclusive" },
		}, RARITIES)

		T.expect(#model.outcomes):toEqual(4)
		local total = 0
		local byId = {}
		for _, outcome in model.outcomes do
			total += outcome.probability
			byId[outcome.itemId] = outcome.probability
		end
		T.expect(total):toBeNear(1, 0.000001)
		T.expect(byId.CommonA):toBeNear(0.35, 0.000001)
		T.expect(byId.CommonB):toBeNear(0.35, 0.000001)
		T.expect(byId.RareA):toBeNear(0.24, 0.000001)
		T.expect(byId.LegendaryA):toBeNear(0.06, 0.000001)
		T.expect(byId.ExclusiveA):toBeNil()
	end)
end)

return true
