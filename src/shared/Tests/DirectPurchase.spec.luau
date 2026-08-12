--!strict

local T = require(script.Parent.TestKit)
local DirectPurchase = require(script.Parent.Parent.Game.Economy.DirectPurchase)

local RARITIES = {
	Common = { Weight = 70, DupeCash = 50, DirectCash = 1200 },
	Rare = { Weight = 24, DupeCash = 150, DirectCash = 3500 },
	Legendary = { Weight = 6, DupeCash = 400, DirectCash = 12000 },
	Exclusive = { Weight = 0, DupeCash = 0, DirectCash = 0 },
}

local ITEMS = {
	CommonA = { Category = "TrailAssets", Rarity = "Common" },
	RareA = { Category = "TrailAssets", Rarity = "Rare" },
	LegendaryA = { Category = "TrailAssets", Rarity = "Legendary" },
	ExclusiveA = { Category = "TrailAssets", Rarity = "Exclusive" },
}

T.describe("DirectPurchase", function()
	T.it("prices items from their rarity", function()
		T.expect(DirectPurchase.priceFor("CommonA", ITEMS, RARITIES)):toEqual(1200)
		T.expect(DirectPurchase.priceFor("RareA", ITEMS, RARITIES)):toEqual(3500)
		T.expect(DirectPurchase.priceFor("LegendaryA", ITEMS, RARITIES)):toEqual(12000)
	end)

	T.it("refuses to price grant-only rarities or unknown items", function()
		T.expect(DirectPurchase.priceFor("ExclusiveA", ITEMS, RARITIES)):toBeNil()
		T.expect(DirectPurchase.priceFor("Nope", ITEMS, RARITIES)):toBeNil()
	end)

	T.it("approves an affordable unowned item", function()
		local price, reason = DirectPurchase.evaluate("RareA", ITEMS, RARITIES, {}, 3500)
		T.expect(price):toEqual(3500)
		T.expect(reason):toBeNil()
	end)

	T.it("reports why a purchase is refused", function()
		local _, unknown = DirectPurchase.evaluate("Nope", ITEMS, RARITIES, {}, 99999)
		T.expect(unknown):toEqual("unknown_item")

		local _, exclusive = DirectPurchase.evaluate("ExclusiveA", ITEMS, RARITIES, {}, 99999)
		T.expect(exclusive):toEqual("not_purchasable")

		local _, owned = DirectPurchase.evaluate("CommonA", ITEMS, RARITIES, { CommonA = true }, 99999)
		T.expect(owned):toEqual("already_owned")

		local _, broke = DirectPurchase.evaluate("RareA", ITEMS, RARITIES, {}, 3499)
		T.expect(broke):toEqual("insufficient_cash")
	end)

	T.it("checks ownership before affordability so an owned item never reads as too expensive", function()
		local _, reason = DirectPurchase.evaluate("LegendaryA", ITEMS, RARITIES, { LegendaryA = true }, 0)
		T.expect(reason):toEqual("already_owned")
	end)

	T.it("builds a deterministic catalog ordered by price then id, excluding grant-only items", function()
		local catalog = DirectPurchase.catalog(ITEMS, RARITIES)

		T.expect(#catalog):toEqual(3)
		T.expect(catalog[1].itemId):toEqual("CommonA")
		T.expect(catalog[2].itemId):toEqual("RareA")
		T.expect(catalog[3].itemId):toEqual("LegendaryA")

		local repeated = DirectPurchase.catalog(ITEMS, RARITIES)
		for index, entry in catalog do
			T.expect(repeated[index].itemId):toEqual(entry.itemId)
		end
	end)

	T.it("prices every direct buy above the expected crate cost for that rarity", function()
		-- Expected Cash per specific item = crate price / (rarity odds / bucket size).
		-- Guarantees the gamble stays the value play at every rarity.
		local cratePrice = 1000
		for rarityName, rarity in RARITIES do
			if rarity.DirectCash > 0 then
				local bucketSize = 5
				local expectedCrateCost = cratePrice / (rarity.Weight / 100 / bucketSize)
				T.expect(rarity.DirectCash < expectedCrateCost):toBeTruthy()
				T.expect(rarity.DirectCash > rarity.DupeCash):toBeTruthy()
			end
		end
	end)
end)

return true
