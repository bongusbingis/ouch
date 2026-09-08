-- Description: Spec guarding the shipped crate configuration: disclosed odds summing to exactly one hundred, pity only for droppable rarities, and the price guarantees between direct buying and crate chasing.

--!strict

local T = require(script.Parent.TestKit)
local Crates = require(script.Parent.Parent.Parent.Config.Economy.Crates)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)
local Shop = require(script.Parent.Parent.Parent.Config.Economy.Shop)
local LiveConfig = require(script.Parent.Parent.Parent.Config.LiveConfig)
local CrateOdds = require(script.Parent.Parent.Game.Economy.CrateOdds)
local FeaturedRotation = require(script.Parent.Parent.Game.Economy.FeaturedRotation)

local function activeCrates()
	local active = {}
	for crateId, crate in Crates do
		if crate.CatalogStatus == "Active" then
			active[crateId] = crate
		end
	end
	return active
end

local function cheapestDirect(): number
	local cheapest = math.huge
	for _, rarity in Cosmetics.Rarities do
		if rarity.DirectBonks > 0 then
			cheapest = math.min(cheapest, rarity.DirectBonks)
		end
	end
	return cheapest
end

local function liveBound(key: string, field: string): number?
	for _, entry in LiveConfig.Entries do
		if entry.Key == key then
			return (entry :: any)[field]
		end
	end
	return nil
end

T.describe("Crate configuration", function()
	T.it("ships at least one crate that can actually be opened", function()
		local count = 0
		for _ in activeCrates() do
			count += 1
		end
		T.expect(count > 0):toBeTruthy()
	end)

	T.it("gives every crate a valid status and only empties the ones nobody can open", function()
		for crateId, crate in Crates do
			local status = crate.CatalogStatus
			T.expect(status == "Active" or status == "Preview" or status == "Hidden"):toBeTruthy()
			if status == "Active" then
				T.expect(#crate.ItemPool > 0):toBeTruthy()
			end
			T.expect(type(crateId)):toEqual("string")
		end
	end)

	T.it("discloses item odds summing to exactly 100 for every openable crate", function()
		for _, crate in activeCrates() do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			local total = 0
			for _, percent in CrateOdds.percentByItem(model, 2) do
				total += percent
			end
			T.expect(math.round(total * 1000)):toEqual(100000)
		end
	end)

	T.it("discloses rarity odds summing to exactly 100 for every openable crate", function()
		for _, crate in activeCrates() do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			local total = 0
			for _, percent in CrateOdds.percentByRarity(model, Cosmetics.Rarities, 1) do
				total += percent
			end
			T.expect(math.round(total * 1000)):toEqual(100000)
		end
	end)

	T.it("gives every openable crate more than one rarity to chase", function()
		for _, crate in activeCrates() do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			T.expect(#model.rarityOrder > 1):toBeTruthy()
		end
	end)

	T.it("only promises pity for rarities the crate can actually drop", function()
		for _, crate in activeCrates() do
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			for rarityName, threshold in crate.Pity or {} do
				T.expect(model.buckets[rarityName] ~= nil):toBeTruthy()
				T.expect(threshold > 0):toBeTruthy()
			end
		end
	end)

	T.it("keeps direct buying cheaper than chasing one specific item through crates", function()
		for _, crate in activeCrates() do
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
		local cheapest = cheapestDirect()
		for _, crate in Crates do
			if crate.BonksPrice ~= nil then
				T.expect(crate.BonksPrice < cheapest):toBeTruthy()
			end
		end
	end)

	T.it("holds both price guarantees at the discounted price actually charged", function()
		for crateId, crate in activeCrates() do
			local price = crate.BonksPrice
			if price ~= nil then
				local charged = FeaturedRotation.discountedPrice(price, Shop.Featured.DiscountPercent)
				T.expect(charged <= price):toBeTruthy()
				T.expect(charged < cheapestDirect()):toBeTruthy()
				local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
				for _, outcome in model.outcomes do
					local directBonks = Cosmetics.Rarities[outcome.rarity].DirectBonks
					if directBonks > 0 then
						T.expect(directBonks < charged / outcome.probability):toBeTruthy()
					end
				end
				T.expect(type(crateId)):toEqual("string")
			end
		end
	end)

	T.it("bounds every live crate price so an A/B variant cannot break either guarantee", function()
		local worstDiscount = liveBound("Shop.Featured.DiscountPercent", "Maximum")
		T.expect(worstDiscount ~= nil):toBeTruthy()
		local cheapest = cheapestDirect()
		for crateId, crate in activeCrates() do
			local key = `Crates.{crateId}.BonksPrice`
			local minimum = liveBound(key, "Minimum")
			local maximum = liveBound(key, "Maximum")
			T.expect(minimum ~= nil):toBeTruthy()
			T.expect(maximum ~= nil):toBeTruthy()

			local floorPrice = FeaturedRotation.discountedPrice(minimum :: number, worstDiscount :: number)
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			for _, outcome in model.outcomes do
				local directBonks = Cosmetics.Rarities[outcome.rarity].DirectBonks
				if directBonks > 0 then
					T.expect(directBonks < floorPrice / outcome.probability):toBeTruthy()
				end
			end
			T.expect((maximum :: number) < cheapest):toBeTruthy()
		end
	end)
end)

return true
