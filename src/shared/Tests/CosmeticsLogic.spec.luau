--!strict

local T = require(script.Parent.TestKit)
local CosmeticsLogic = require(script.Parent.Parent.Game.Economy.CosmeticsLogic)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)
local Crates = require(script.Parent.Parent.Parent.Config.Crates)
local GamePasses = require(script.Parent.Parent.Parent.Config.GamePasses)

local ITEMS = {
	BallRed = { Category = "BallAssets", Rarity = "Common" },
	HammerGold = { Category = "HammerAssets", Rarity = "Rare" },
}

local SLOTS = { BallAssets = true, HammerAssets = true }

T.describe("CosmeticsLogic", function()
	T.it("configures category-folder defaults", function()
		T.expect(Cosmetics.Defaults.BallAssets.AssetName):toEqual("DefaultDodgeball")
		T.expect(Cosmetics.Defaults.HammerAssets.AssetName):toEqual("DefaultHammer")
	end)

	T.it("registers renderable trail cosmetics in every rarity", function()
		local counts = { Common = 0, Rare = 0, Legendary = 0, Exclusive = 0 }
		for _, item in Cosmetics.Items do
			if item.Category == "TrailAssets" then
				counts[item.Rarity] += 1
				T.expect(item.EffectId ~= nil):toBeTruthy()
			end
		end
		for _, count in counts do
			T.expect(count > 0):toBeTruthy()
		end
	end)

	T.it("makes every Exclusive cosmetic obtainable from some game pass", function()
		-- Exclusives never drop from crates and are not directly purchasable, so
		-- one that no pass grants is unobtainable dead content.
		local granted = {}
		for _, definition in GamePasses.Catalog do
			for _, itemId in definition.EntitlementItemIds do
				granted[itemId] = true
			end
		end
		for itemId, item in Cosmetics.Items do
			if item.Rarity == "Exclusive" then
				T.expect(granted[itemId]):toEqual(true)
			end
		end
	end)

	T.it("only lists cosmetics that exist, in categories each pass declares", function()
		for _, definition in GamePasses.Catalog do
			local allowed = {}
			for _, category in definition.Categories do
				allowed[category] = true
			end
			for _, itemId in definition.EntitlementItemIds do
				local item = Cosmetics.Items[itemId]
				T.expect(item ~= nil):toBeTruthy()
				T.expect(allowed[item.Category]):toEqual(true)
			end
		end
	end)

	T.it("keeps every Exclusive trail out of the crate pools", function()
		for _, crate in Crates do
			for _, itemId in crate.ItemPool do
				local item = Cosmetics.Items[itemId]
				T.expect(item ~= nil):toBeTruthy()
				if item.Rarity == "Exclusive" then
					T.expect(Cosmetics.Rarities.Exclusive.Weight):toEqual(0)
				end
			end
		end
	end)

	T.it("allows equipping an owned item into its matching slot", function()
		local ok, reason = CosmeticsLogic.canEquip(ITEMS, SLOTS, { BallRed = true }, "BallAssets", "BallRed")
		T.expect(ok):toEqual(true)
		T.expect(reason):toBeNil()
	end)

	T.it("allows unequipping any valid slot", function()
		local ok = CosmeticsLogic.canEquip(ITEMS, SLOTS, {}, "BallAssets", nil)
		T.expect(ok):toEqual(true)
	end)

	T.it("rejects invalid slots, unknown items, wrong slots, and unowned items", function()
		local cases: { { any } } = {
			{ "Nope", "BallRed", "invalid_slot" },
			{ "BallAssets", "Missing", "unknown_item" },
			{ "HammerAssets", "BallRed", "wrong_slot" },
			{ "BallAssets", "BallRed", "not_owned" },
		}
		for _, case in cases do
			local ok, reason = CosmeticsLogic.canEquip(ITEMS, SLOTS, {}, case[1], case[2])
			T.expect(ok):toEqual(false)
			T.expect(reason):toEqual(case[3])
		end
	end)
end)

return true
