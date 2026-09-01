-- Name: CrateRolls.spec.luau
-- Author: Jack C.
-- Description: Spec for crate rolling against a scripted random source: weighted rarity distribution, zero-weight exclusion, duplicate refunds, and the pity guarantee bounding the worst-case streak.
-- Created: 2026-07-13

--!strict

local T = require(script.Parent.TestKit)
local CrateRolls = require(script.Parent.Parent.Game.Economy.CrateRolls)

local RARITIES = {
	Common = { Weight = 70, DupeBonks = 50 },
	Rare = { Weight = 24, DupeBonks = 150 },
	Legendary = { Weight = 6, DupeBonks = 400 },
	Exclusive = { Weight = 0, DupeBonks = 0 },
}

local ITEMS = {
	CommonA = { Category = "BallAssets", Rarity = "Common" },
	CommonB = { Category = "BallAssets", Rarity = "Common" },
	RareA = { Category = "BallAssets", Rarity = "Rare" },
	LegendaryA = { Category = "BallAssets", Rarity = "Legendary" },
	ExclusiveA = { Category = "BallAssets", Rarity = "Exclusive" },
}

local CRATE = { ItemPool = { "CommonA", "CommonB", "RareA", "LegendaryA", "ExclusiveA" } }

local function scriptedRandom(numbers: { number }, integers: { number })
	local numberIndex = 0
	local integerIndex = 0
	return {
		NextNumber = function(_self): number
			numberIndex += 1
			return numbers[numberIndex] or 0
		end,
		NextInteger = function(_self, min: number, max: number): number
			integerIndex += 1
			return math.clamp(integers[integerIndex] or min, min, max)
		end,
	} :: any
end

T.describe("CrateRolls", function()
	T.it("rolls rarities according to weights", function()
		local common = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, scriptedRandom({ 0.5 }, { 1 }))
		T.expect(common.rarity):toEqual("Common")

		local legendary = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, scriptedRandom({ 0.75 }, { 1 }))
		T.expect(legendary.rarity):toEqual("Legendary")

		local rare = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, scriptedRandom({ 0.99 }, { 1 }))
		T.expect(rare.rarity):toEqual("Rare")
	end)

	T.it("never rolls zero-weight (Exclusive) items", function()
		for trial = 1, 50 do
			local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, scriptedRandom({ (trial - 1) / 50 }, { trial }))
			T.expect(result.itemId ~= "ExclusiveA"):toBeTruthy()
		end
	end)

	T.it("refunds dupes by rarity and grants nothing new", function()
		local owned = { CommonA = true }
		local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, owned, scriptedRandom({ 0 }, { 1 }))
		T.expect(result.itemId):toEqual("CommonA")
		T.expect(result.isDupe):toEqual(true)
		T.expect(result.bonksRefund):toEqual(50)
	end)

	T.it("returns zero refund for fresh items", function()
		local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, scriptedRandom({ 0 }, { 2 }))
		T.expect(result.itemId):toEqual("CommonB")
		T.expect(result.isDupe):toEqual(false)
		T.expect(result.bonksRefund):toEqual(0)
	end)

	T.it("leaves crates without a Pity block rolling exactly as before", function()
		local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, scriptedRandom({ 0.5 }, { 1 }))
		T.expect(result.rarity):toEqual("Common")
		T.expect(result.pityTriggered):toBeNil()
		T.expect(next(result.pity)):toBeNil()
	end)

	T.it("forces the guaranteed rarity once its threshold comes due", function()
		local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
		local result = CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, scriptedRandom({ 0.5 }, { 1 }), { Rare = 4 })
		T.expect(result.rarity):toEqual("Rare")
		T.expect(result.pityTriggered):toEqual("Rare")
		T.expect(result.pity.Rare):toEqual(0)
	end)

	T.it("counts up to the guarantee and resets on a natural hit", function()
		local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }

		local counters = {}
		for open = 1, 3 do
			local result = CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, scriptedRandom({ 0.5 }, { 1 }), counters)
			T.expect(result.rarity):toEqual("Common")
			T.expect(result.pity.Rare):toEqual(open)
			counters = result.pity
		end

		local natural = CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, scriptedRandom({ 0.99 }, { 1 }), counters)
		T.expect(natural.rarity):toEqual("Rare")
		T.expect(natural.pityTriggered):toBeNil()
		T.expect(natural.pity.Rare):toEqual(0)
		T.expect(natural.pity.Legendary):toEqual(4)
	end)

	T.it("treats a rarer drop as satisfying the weaker guarantee", function()
		local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
		local result = CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, scriptedRandom({ 0.75 }, { 1 }), { Rare = 3 })
		T.expect(result.rarity):toEqual("Legendary")
		T.expect(result.pity.Rare):toEqual(0)
		T.expect(result.pity.Legendary):toEqual(0)
	end)

	T.it("prefers the rarest guarantee when two come due together", function()
		local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
		local result = CrateRolls.roll(
			pityCrate,
			ITEMS,
			RARITIES,
			{},
			scriptedRandom({ 0.5 }, { 1 }),
			{ Rare = 4, Legendary = 24 }
		)
		T.expect(result.rarity):toEqual("Legendary")
		T.expect(result.pityTriggered):toEqual("Legendary")
	end)

	T.it("bounds the worst-case streak to the configured thresholds", function()
		local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
		local counters = {}
		local sinceRare = 0
		local sinceLegendary = 0

		for _ = 1, 200 do
			local result = CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, scriptedRandom({ 0.5 }, { 1 }), counters)
			counters = result.pity
			sinceRare = if RARITIES[result.rarity].Weight <= RARITIES.Rare.Weight then 0 else sinceRare + 1
			sinceLegendary = if result.rarity == "Legendary" then 0 else sinceLegendary + 1
			T.expect(sinceRare < 5):toBeTruthy()
			T.expect(sinceLegendary < 25):toBeTruthy()
		end
	end)

	T.it("rejects crates with no rollable items", function()
		local emptyCrate = { ItemPool = { "ExclusiveA" } }
		local ok = pcall(function()
			CrateRolls.roll(emptyCrate, ITEMS, RARITIES, {}, scriptedRandom({ 0 }, { 1 }))
		end)
		T.expect(ok):toEqual(false)
	end)
end)

return true
