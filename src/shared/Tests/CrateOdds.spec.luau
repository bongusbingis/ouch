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

	T.it("allocates item percentages that sum to exactly 100 when shares do not divide evenly", function()
		local pool = {}
		local items = {}
		for index = 1, 9 do
			local itemId = `Common{index}`
			table.insert(pool, itemId)
			items[itemId] = { Rarity = "Common" }
		end
		local model = CrateOdds.build({ ItemPool = pool }, items, RARITIES)

		for _, precision in { 0, 1, 2, 3 } do
			local percents = CrateOdds.percentByItem(model, precision)
			local total = 0
			for _, percent in percents do
				total += percent
			end
			T.expect(math.round(total * 1000)):toEqual(100000)
		end
	end)

	T.it("allocates rarity percentages that sum to exactly 100", function()
		local model = CrateOdds.build({
			ItemPool = { "CommonA", "RareA", "RareB", "LegendaryA" },
		}, {
			CommonA = { Rarity = "Common" },
			RareA = { Rarity = "Rare" },
			RareB = { Rarity = "Rare" },
			LegendaryA = { Rarity = "Legendary" },
		}, RARITIES)

		for _, precision in { 0, 1, 2 } do
			local percents = CrateOdds.percentByRarity(model, RARITIES, precision)
			local total = 0
			for _, percent in percents do
				total += percent
			end
			T.expect(math.round(total * 1000)):toEqual(100000)
		end
	end)

	T.it("keeps allocation deterministic across repeated builds", function()
		local pool = { "A", "B", "C", "D", "E", "F", "G" }
		local items = {}
		for _, itemId in pool do
			items[itemId] = { Rarity = "Common" }
		end

		local first = CrateOdds.percentByItem(CrateOdds.build({ ItemPool = pool }, items, RARITIES), 2)
		local second = CrateOdds.percentByItem(CrateOdds.build({ ItemPool = pool }, items, RARITIES), 2)
		for itemId, percent in first do
			T.expect(second[itemId]):toEqual(percent)
		end
	end)

	T.it("formats whole percentages without decimals", function()
		T.expect(CrateOdds.formatPercent(25, 2)):toEqual("25")
		T.expect(CrateOdds.formatPercent(11.11, 2)):toEqual("11.11")
		T.expect(CrateOdds.formatPercent(7.9, 1)):toEqual("7.9")
	end)
end)

return true
