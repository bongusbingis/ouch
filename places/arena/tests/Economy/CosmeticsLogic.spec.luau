-- Name: CosmeticsLogic.spec.luau
-- Author: Jack C.
-- Description: In-place port of the cosmetics equip-validation spec, covering slot and ownership rules and the configured category defaults.
-- Created: 2026-07-16

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local CosmeticsLogic = require(Shared:WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))

local ITEMS = {
	BallRed = { Category = "BallAssets", Rarity = "Common" },
	HammerGold = { Category = "HammerAssets", Rarity = "Rare" },
}

local SLOTS = { BallAssets = true, HammerAssets = true }

return function()
	describe("CosmeticsLogic", function()
		it("configures shared visual defaults", function()
			expect(Cosmetics.Defaults.BallAssets.Visual.Template).to.equal("Dodgeball")
			expect(Cosmetics.Defaults.HammerAssets.Visual.Template).to.equal("Hammer")
			expect(Cosmetics.VisualTemplates.Dodgeball.MeshId).to.equal(126364964183882)
			expect(Cosmetics.VisualTemplates.Hammer.MeshId).to.equal(95803748037612)
		end)

		it("allows equipping an owned item into its matching slot", function()
			local ok, reason = CosmeticsLogic.canEquip(ITEMS, SLOTS, { BallRed = true }, "BallAssets", "BallRed")
			expect(ok).to.equal(true)
			expect(reason).never.to.be.ok()
		end)

		it("allows equipping owned items in every configured slot", function()
			local owned = { BallRed = true, HammerGold = true }
			expect(CosmeticsLogic.canEquip(ITEMS, SLOTS, owned, "BallAssets", "BallRed")).to.equal(true)
			expect(CosmeticsLogic.canEquip(ITEMS, SLOTS, owned, "HammerAssets", "HammerGold")).to.equal(true)
		end)

		it("allows unequipping any valid slot", function()
			local ok = CosmeticsLogic.canEquip(ITEMS, SLOTS, {}, "BallAssets", nil)
			expect(ok).to.equal(true)
		end)

		it("allows always-available cosmetics without ownership", function()
			local items = { Red = { Category = "CharacterColor", AlwaysAvailable = true } }
			local ok, reason = CosmeticsLogic.canEquip(items, { CharacterColor = true }, {}, "CharacterColor", "Red")
			expect(ok).to.equal(true)
			expect(reason).never.to.be.ok()
		end)

		it("rejects invalid slots, unknown items, wrong slots, and unowned items", function()
			local cases = {
				{ "Nope", "BallRed", "invalid_slot" },
				{ "BallAssets", "Missing", "unknown_item" },
				{ "HammerAssets", "BallRed", "wrong_slot" },
				{ "BallAssets", "BallRed", "not_owned" },
			}
			for _, case in cases do
				local ok, reason = CosmeticsLogic.canEquip(ITEMS, SLOTS, {}, case[1], case[2])
				expect(ok).to.equal(false)
				expect(reason).to.equal(case[3])
			end
		end)
	end)
end
