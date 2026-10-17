-- Description: In-place port of the crate roll spec, pinning the weighted rarity distribution, zero-weight exclusion, dupe refunds, the pity guarantee bounding the worst-case streak, and empty-pool rejection with a scripted random source.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local CrateRolls = require(Shared:WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateRolls"))
local ScriptedRandom =
	require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("ScriptedRandom"))

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

return function()
	describe("CrateRolls", function()
		it("rolls rarities according to weights", function()
			local common = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.5 }, { 1 }))
			expect(common.rarity).to.equal("Common")

			local legendary = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.75 }, { 1 }))
			expect(legendary.rarity).to.equal("Legendary")

			local rare = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.99 }, { 1 }))
			expect(rare.rarity).to.equal("Rare")
		end)

		it("resolves the exact rarity boundaries deterministically", function()
			local atCommonEdge = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.699 }, { 1 }))
			expect(atCommonEdge.rarity).to.equal("Common")

			local pastCommonEdge = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.701 }, { 1 }))
			expect(pastCommonEdge.rarity).to.equal("Legendary")

			local pastLegendaryEdge = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.761 }, { 1 }))
			expect(pastLegendaryEdge.rarity).to.equal("Rare")
		end)

		it("never rolls zero-weight (Exclusive) items", function()
			for trial = 1, 50 do
				local result =
					CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ (trial - 1) / 50 }, { trial }))
				expect(result.itemId ~= "ExclusiveA").to.equal(true)
			end
		end)

		it("refunds dupes by rarity and grants nothing new", function()
			local owned = { CommonA = true }
			local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, owned, ScriptedRandom.new({ 0 }, { 1 }))
			expect(result.itemId).to.equal("CommonA")
			expect(result.isDupe).to.equal(true)
			expect(result.bonksRefund).to.equal(50)
		end)

		it("uses the rolled item's own rarity for the refund amount", function()
			local owned = { LegendaryA = true }
			local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, owned, ScriptedRandom.new({ 0.75 }, { 1 }))
			expect(result.itemId).to.equal("LegendaryA")
			expect(result.isDupe).to.equal(true)
			expect(result.bonksRefund).to.equal(400)
		end)

		it("returns zero refund for fresh items", function()
			local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0 }, { 2 }))
			expect(result.itemId).to.equal("CommonB")
			expect(result.isDupe).to.equal(false)
			expect(result.bonksRefund).to.equal(0)
		end)

		it("rejects crates with no rollable items", function()
			local emptyCrate = { ItemPool = { "ExclusiveA" } }
			expect(function()
				CrateRolls.roll(emptyCrate, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0 }, { 1 }))
			end).to.throw()
		end)

		it("leaves crates without a Pity block rolling exactly as before", function()
			local result = CrateRolls.roll(CRATE, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.5 }, { 1 }))
			expect(result.rarity).to.equal("Common")
			expect(result.pityTriggered).to.equal(nil)
			expect(next(result.pity)).to.equal(nil)
		end)

		it("forces the guaranteed rarity once its threshold comes due", function()
			local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
			local result = CrateRolls.roll(
				pityCrate,
				ITEMS,
				RARITIES,
				{},
				ScriptedRandom.new({ 0.5 }, { 1 }),
				{ Rare = 4 }
			)
			expect(result.rarity).to.equal("Rare")
			expect(result.pityTriggered).to.equal("Rare")
			expect(result.pity.Rare).to.equal(0)
		end)

		it("counts up to the guarantee and resets on a natural hit", function()
			local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }

			local counters = {}
			for open = 1, 3 do
				local result =
					CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.5 }, { 1 }), counters)
				expect(result.rarity).to.equal("Common")
				expect(result.pity.Rare).to.equal(open)
				counters = result.pity
			end

			local natural =
				CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.99 }, { 1 }), counters)
			expect(natural.rarity).to.equal("Rare")
			expect(natural.pityTriggered).to.equal(nil)
			expect(natural.pity.Rare).to.equal(0)
			expect(natural.pity.Legendary).to.equal(4)
		end)

		it("treats a rarer drop as satisfying the weaker guarantee", function()
			local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
			local result = CrateRolls.roll(
				pityCrate,
				ITEMS,
				RARITIES,
				{},
				ScriptedRandom.new({ 0.75 }, { 1 }),
				{ Rare = 3 }
			)
			expect(result.rarity).to.equal("Legendary")
			expect(result.pity.Rare).to.equal(0)
			expect(result.pity.Legendary).to.equal(0)
		end)

		it("prefers the rarest guarantee when two come due together", function()
			local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
			local result = CrateRolls.roll(
				pityCrate,
				ITEMS,
				RARITIES,
				{},
				ScriptedRandom.new({ 0.5 }, { 1 }),
				{ Rare = 4, Legendary = 24 }
			)
			expect(result.rarity).to.equal("Legendary")
			expect(result.pityTriggered).to.equal("Legendary")
		end)

		it("bounds the worst-case streak to the configured thresholds", function()
			local pityCrate = { ItemPool = CRATE.ItemPool, Pity = { Rare = 5, Legendary = 25 } }
			local counters = {}
			local sinceRare = 0
			local sinceLegendary = 0

			for _ = 1, 200 do
				local result =
					CrateRolls.roll(pityCrate, ITEMS, RARITIES, {}, ScriptedRandom.new({ 0.5 }, { 1 }), counters)
				counters = result.pity
				sinceRare = if RARITIES[result.rarity].Weight <= RARITIES.Rare.Weight then 0 else sinceRare + 1
				sinceLegendary = if result.rarity == "Legendary" then 0 else sinceLegendary + 1
				expect(sinceRare < 5).to.equal(true)
				expect(sinceLegendary < 25).to.equal(true)
			end
		end)
	end)
end
