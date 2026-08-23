--!strict

-- Guards the shipped crate configuration rather than synthetic fixtures: the
-- odds-disclosure and pity guarantees are published to players, so they must
-- hold for the real pools.
--
-- Only Active crates are checked. A Preview crate is merchandised as coming
-- soon and cannot be opened, and its pool is empty until its content exists --
-- building an odds model for one is exactly the assert CrateOdds is meant to
-- raise, not a case to tolerate.

local T = require(script.Parent.TestKit)
local Crates = require(script.Parent.Parent.Parent.Config.Crates)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)
local Shop = require(script.Parent.Parent.Parent.Config.Shop)
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
		-- If targeting an item cost more than gambling for it, the guaranteed
		-- path would be pointless and nobody would ever take it.
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
		-- The inverse guard: crates must stay the value play for breadth, or
		-- there is no reason to open one.
		local cheapest = cheapestDirect()
		for _, crate in Crates do
			if crate.BonksPrice ~= nil then
				T.expect(crate.BonksPrice < cheapest):toBeTruthy()
			end
		end
	end)

	T.it("holds both price guarantees at the discounted price actually charged", function()
		-- The two guards above read the baked BonksPrice, but a featured crate is
		-- charged less than that, so the discounted price is the one a player
		-- really pays. Checked explicitly because nothing else covers it.
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
		-- Crate prices and the featured discount are live-overridable, so the
		-- guarantees have to survive the worst combination the allowlist permits,
		-- not just the baked one. Without this, an experiment could quietly make
		-- crates a worse deal than buying outright.
		local worstDiscount = liveBound("Shop.Featured.DiscountPercent", "Maximum")
		T.expect(worstDiscount ~= nil):toBeTruthy()
		local cheapest = cheapestDirect()
		for crateId, crate in activeCrates() do
			local key = `Crates.{crateId}.BonksPrice`
			local minimum = liveBound(key, "Minimum")
			local maximum = liveBound(key, "Maximum")
			T.expect(minimum ~= nil):toBeTruthy()
			T.expect(maximum ~= nil):toBeTruthy()

			-- Cheapest a player could ever be charged: lowest allowed price, then
			-- the deepest allowed discount on top.
			local floorPrice = FeaturedRotation.discountedPrice(minimum :: number, worstDiscount :: number)
			local model = CrateOdds.build(crate, Cosmetics.Items, Cosmetics.Rarities)
			for _, outcome in model.outcomes do
				local directBonks = Cosmetics.Rarities[outcome.rarity].DirectBonks
				if directBonks > 0 then
					T.expect(directBonks < floorPrice / outcome.probability):toBeTruthy()
				end
			end
			-- Dearest it could ever be, which must still beat a direct buy.
			T.expect((maximum :: number) < cheapest):toBeTruthy()
		end
	end)
end)

return true
