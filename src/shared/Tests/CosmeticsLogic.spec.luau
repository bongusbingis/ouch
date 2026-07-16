--!strict

local T = require(script.Parent.TestKit)
local CosmeticsLogic = require(script.Parent.Parent.Game.Economy.CosmeticsLogic)

local ITEMS = {
	BallRed = { Category = "BallAssets", Rarity = "Common" },
	HammerGold = { Category = "HammerAssets", Rarity = "Rare" },
}

local SLOTS = { BallAssets = true, HammerAssets = true }

T.describe("CosmeticsLogic", function()
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
