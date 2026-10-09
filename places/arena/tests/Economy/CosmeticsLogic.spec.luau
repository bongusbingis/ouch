-- Description: In-place port of the cosmetics equip-validation spec, covering slot and ownership rules, category defaults, crate pool rarity spread, and that every exclusive item is obtainable and backed by real audio.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local CosmeticsLogic = require(Shared:WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Crates"))
local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("GamePasses"))
local Audio = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Audio"))

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

		it("provides six ordered character colors without ownership", function()
			local entries = {
				{
					name = Cosmetics.Defaults.CharacterColor.DisplayName,
					order = Cosmetics.Defaults.CharacterColor.SortOrder,
				},
			}
			for _, item in Cosmetics.Items do
				if item.Category == "CharacterColor" then
					expect(item.AlwaysAvailable).to.equal(true)
					table.insert(entries, { name = item.DisplayName, order = item.SortOrder })
				end
			end
			table.sort(entries, function(left, right)
				return left.order < right.order
			end)
			expect(#entries).to.equal(6)
			expect(entries[1].name).to.equal("Red")
			expect(entries[3].name).to.equal("Cyan")
			expect(entries[6].name).to.equal("Purple")
		end)

		it("spreads every openable crate's pool across more than one rarity", function()
			for _, crate in Crates do
				if crate.CatalogStatus == "Active" then
					local rarities = {}
					for _, itemId in crate.ItemPool do
						local item = Cosmetics.Items[itemId]
						expect(item ~= nil).to.equal(true)
						rarities[item.Rarity] = true
					end
					local distinct = 0
					for _ in rarities do
						distinct += 1
					end
					expect(distinct > 1).to.equal(true)
				end
			end
		end)

		it("gives every equip slot that has items a default or an always-available entry", function()
			local populated = {}
			for _, item in Cosmetics.Items do
				if item.AlwaysAvailable ~= true then
					populated[item.Category] = true
				end
			end
			for slot in populated do
				expect(Cosmetics.Defaults[slot] ~= nil).to.equal(true)
			end
		end)

		it("gives the default elimination effect sounds that Config.Audio actually defines", function()
			local default = Cosmetics.Defaults.ElimEffectAssets
			expect(default ~= nil).to.equal(true)
			local effect = default.ElimEffect
			expect(effect ~= nil).to.equal(true)
			expect(Audio.Gameplay[effect.DodgeballSound] ~= nil).to.equal(true)
			expect(Audio.Gameplay[effect.HammerSound] ~= nil).to.equal(true)
		end)

		it("points every elimination effect cosmetic at real audio entries", function()
			for _, item in Cosmetics.Items do
				if item.Category == "ElimEffectAssets" then
					expect(item.ElimEffect ~= nil).to.equal(true)
					local dodgeball = Audio.Gameplay[item.ElimEffect.DodgeballSound]
					local hammer = Audio.Gameplay[item.ElimEffect.HammerSound]
					expect(dodgeball ~= nil).to.equal(true)
					expect(hammer ~= nil).to.equal(true)
					expect(dodgeball.Scope).to.equal("World")
					expect(hammer.Scope).to.equal("World")
					expect(#dodgeball.AssetIds > 0).to.equal(true)
					expect(#hammer.AssetIds > 0).to.equal(true)
				end
			end
		end)

		it("plays one consolidated sound for both weapons, default included", function()
			local default = Cosmetics.Defaults.ElimEffectAssets.ElimEffect
			expect(default.DodgeballSound).to.equal(default.HammerSound)
			for _, item in Cosmetics.Items do
				if item.Category == "ElimEffectAssets" then
					expect(item.ElimEffect.DodgeballSound).to.equal(item.ElimEffect.HammerSound)
				end
			end
		end)

		it("makes every Exclusive cosmetic obtainable from some game pass in covered categories", function()
			local granted = {}
			local coveredCategories = {}
			for _, definition in GamePasses.Catalog do
				for _, category in definition.Categories do
					coveredCategories[category] = true
				end
				for _, itemId in definition.EntitlementItemIds do
					granted[itemId] = true
				end
			end
			for itemId, item in Cosmetics.Items do
				if item.Rarity == "Exclusive" and coveredCategories[item.Category] then
					expect(granted[itemId]).to.equal(true)
				end
			end
		end)

		it("only lists cosmetics that exist, in categories each pass declares", function()
			for _, definition in GamePasses.Catalog do
				local allowed = {}
				for _, category in definition.Categories do
					allowed[category] = true
				end
				for _, itemId in definition.EntitlementItemIds do
					local item = Cosmetics.Items[itemId]
					expect(item ~= nil).to.equal(true)
					expect(allowed[item.Category]).to.equal(true)
				end
			end
		end)

		it("keeps every Exclusive cosmetic out of the crate pools", function()
			for _, crate in Crates do
				for _, itemId in crate.ItemPool do
					local item = Cosmetics.Items[itemId]
					expect(item ~= nil).to.equal(true)
					expect(item.Rarity ~= "Exclusive").to.equal(true)
				end
			end
		end)
	end)
end
