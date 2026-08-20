--!strict

-- Guards the shipped crate configuration rather than synthetic fixtures: the
-- odds-disclosure and pity guarantees are published to players, so they must
-- hold for the real pools.

local T = require(script.Parent.TestKit)
local Crates = require(script.Parent.Parent.Parent.Config.Crates)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)
local CrateOdds = require(script.Parent.Parent.Game.Economy.CrateOdds)

T.describe("Crate configuration", function()
	T.it("discloses item odds summing to exactly 100 for every shipped crate", function()
		for _, crate in Crates do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			local total = 0
			for _, percent in CrateOdds.percentByItem(model, 2) do
				total += percent
			end
			T.expect(math.round(total * 1000)):toEqual(100000)
		end
	end)

	T.it("discloses rarity odds summing to exactly 100 for every shipped crate", function()
		for _, crate in Crates do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			local total = 0
			for _, percent in CrateOdds.percentByRarity(model, Cosmetics.Rarities, 1) do
				total += percent
			end
			T.expect(math.round(total * 1000)):toEqual(100000)
		end
	end)

	T.it("gives every shipped crate more than one rarity to chase", function()
		for _, crate in Crates do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			T.expect(#model.rarityOrder > 1):toBeTruthy()
		end
	end)

	T.it("only promises pity for rarities the crate can actually drop", function()
		for _, crate in Crates do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			for rarityName, threshold in crate.Pity or {} do
				T.expect(model.buckets[rarityName] ~= nil):toBeTruthy()
				T.expect(threshold > 0):toBeTruthy()
			end
		end
	end)

	T.it("keeps direct buying cheaper than chasing one specific item through crates", function()
		-- If targeting an item cost more than gambling for it, the guaranteed
		-- path would be pointless and nobody would ever take it.
		for _, crate in Crates do
			local price = crate.BonksPrice
			if price ~= nil then
				local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
				for _, outcome in model.outcomes do
					local directBonks = Cosmetics.Rarities[outcome.rarity].DirectBonks
					if directBonks > 0 then
						T.expect(directBonks < price / outcome.probability):toBeTruthy()
					end
				end
			end
		end
	end)

	T.it("keeps one crate open cheaper than the cheapest direct buy", function()
		-- The inverse guard: crates must stay the value play for breadth, or
		-- there is no reason to open one.
		local cheapestDirect = math.huge
		for _, rarity in Cosmetics.Rarities do
			if rarity.DirectBonks > 0 then
				cheapestDirect = math.min(cheapestDirect, rarity.DirectBonks)
			end
		end
		for _, crate in Crates do
			if crate.BonksPrice ~= nil then
				T.expect(crate.BonksPrice < cheapestDirect):toBeTruthy()
			end
		end
	end)
end)

return true
