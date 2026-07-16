--!strict

local T = require(script.Parent.TestKit)
local CosmeticsLogic = require(script.Parent.Parent.Game.Economy.CosmeticsLogic)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)

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

	T.it("registers five trail cosmetics per rarity", function()
		local counts = { Common = 0, Rare = 0, Legendary = 0, Exclusive = 0 }
		for _, item in Cosmetics.Items do
			if item.Category == "TrailAssets" then
				counts[item.Rarity] += 1
				T.expect(item.EffectId ~= nil):toBeTruthy()
			end
		end
		for _, count in counts do
			T.expect(count):toEqual(5)
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
