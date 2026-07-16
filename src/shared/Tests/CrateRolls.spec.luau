--!strict

local T = require(script.Parent.TestKit)
local CrateRolls = require(script.Parent.Parent.Game.Economy.CrateRolls)

local RARITIES = {
	Common = { Weight = 70, DupeCash = 50 },
	Rare = { Weight = 24, DupeCash = 150 },
	Legendary = { Weight = 6, DupeCash = 400 },
	Exclusive = { Weight = 0, DupeCash = 0 },
}

local ITEMS = {
	CommonA = { Category = "BallAssets", Rarity = "Common" },
	CommonB = { Category = "BallAssets", Rarity = "Common" },
	RareA = { Category = "BallAssets", Rarity = "Rare" },
	LegendaryA = { Category = "BallAssets", Rarity = "Legendary" },
	ExclusiveA = { Category = "BallAssets", Rarity = "Exclusive" },
}

local CRATE = { ItemPool = { "CommonA", "CommonB", "RareA", "LegendaryA", "ExclusiveA" } }

-- Deterministic Random stand-in: NextNumber returns queued fractions [0,1),
-- NextInteger returns queued picks (clamped to range).
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
		-- Sorted rarity order: Common(70), Legendary(6), Rare(24); total 100.
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
		T.expect(result.cashRefund):toEqual(50)
	end)

	T.it("returns zero refund for fresh items", function()
		local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, scriptedRandom({ 0 }, { 2 }))
		T.expect(result.itemId):toEqual("CommonB")
		T.expect(result.isDupe):toEqual(false)
		T.expect(result.cashRefund):toEqual(0)
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
