-- Name: CrateRolls.spec.luau
-- Author: Jack C.
-- Description: In-place port of the crate roll spec, pinning the weighted rarity distribution, zero-weight exclusion, dupe refunds, and empty-pool rejection with a scripted random source.
-- Created: 2026-07-16

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
	end)
end
