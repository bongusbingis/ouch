-- Name: CosmeticEffects.spec.luau
-- Author: Jack C.
-- Description: Spec for the cosmetic VFX registry: every effect category binds to a real slot with a resolvable default, effect-slot cosmetics carry EffectIds, triggers are well-formed, and equipped-effect resolution falls back to the category default.
-- Created: 2026-08-29

--!strict

local T = require(script.Parent.TestKit)
local CosmeticEffectFactory = require(script.Parent.Parent.Game.Cosmetics.CosmeticEffectFactory)
local CosmeticEffects = require(script.Parent.Parent.Parent.Config.CosmeticEffects)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)
local Inventory = require(script.Parent.Parent.Parent.Config.Inventory)

local PRODUCTION_IMPACT_EFFECTS = {
	"StarPop",
	"FoamPoof",
	"ConfettiImpact",
	"JellySplash",
	"SugarRush",
	"PartyPopper",
	"CandyCrash",
	"ComicBonk",
	"BubbleBurst",
	"RoyalParty",
	"Prismatic",
	"Galaxy",
	"Starlight",
}

local function impactCategory()
	local category = CosmeticEffects.Categories.Impact
	T.expect(category ~= nil):toBeTruthy()
	return category
end

T.describe("CosmeticEffects", function()
	T.it("binds every effect category to a real slot with a matching default effect", function()
		for _, category in CosmeticEffects.Categories do
			T.expect(Cosmetics.Slots[category.Slot]):toEqual(true)
			T.expect(#category.FolderName > 0):toBeTruthy()
			T.expect(#category.OwnerField > 0):toBeTruthy()
			T.expect(#category.PositionField > 0):toBeTruthy()
			T.expect(category.DefaultEmitCount >= 0):toBeTruthy()

			local default = Cosmetics.Defaults[category.Slot]
			T.expect(default ~= nil):toBeTruthy()
			T.expect(default.EffectId):toEqual(category.DefaultEffectId)
		end
	end)

	T.it("gives every effect-slot cosmetic a non-empty EffectId", function()
		local slots = {}
		for _, category in CosmeticEffects.Categories do
			slots[category.Slot] = true
		end
		for _, item in Cosmetics.Items do
			if slots[item.Category] then
				T.expect(item.EffectId ~= nil and item.EffectId ~= ""):toBeTruthy()
			end
		end
	end)

	T.it("ships DefaultImpact at an emit count of 5 as the Impact default", function()
		local category = impactCategory()
		T.expect(category.DefaultEffectId):toEqual("DefaultImpact")
		T.expect(category.DefaultEmitCount):toEqual(5)
		T.expect(category.Slot):toEqual("ImpactEffectAssets")
	end)

	T.it("well-forms every trigger", function()
		for _, category in CosmeticEffects.Categories do
			T.expect(#category.Triggers > 0):toBeTruthy()
			for _, trigger in category.Triggers do
				T.expect(typeof(trigger.Event)):toEqual("string")
				if trigger.Match ~= nil then
					T.expect(typeof(trigger.Match)):toEqual("function")
				end
			end
		end
	end)

	T.it("splits Elim so only dodgeball impacts fire, not hammer or zone kills", function()
		local category = impactCategory()
		local elimTrigger, hammerTrigger
		for _, trigger in category.Triggers do
			if trigger.Event == "Elim" then
				elimTrigger = trigger
			elseif trigger.Event == "HammerHit" then
				hammerTrigger = trigger
			end
		end
		T.expect(elimTrigger ~= nil):toBeTruthy()
		T.expect(hammerTrigger ~= nil):toBeTruthy()
		-- A dodgeball elimination carries a projectile; a hammer elimination and an
		-- elimination-zone fall do not, so only the dedicated HammerHit fires melee.
		T.expect(elimTrigger.Match({ projectileId = "7" })):toEqual(true)
		T.expect(elimTrigger.Match({})):toEqual(false)
		T.expect(hammerTrigger.Match):toBeNil()
	end)

	T.it("resolves an equipped effect id and falls back to the default", function()
		local items = {
			ConfettiImpact = { Category = "ImpactEffectAssets", EffectId = "ConfettiImpact" },
			BallRed = { Category = "BallAssets", EffectId = nil },
		}
		local slot = "ImpactEffectAssets"
		T.expect(CosmeticEffectFactory.effectIdForItem(items, slot, "ConfettiImpact")):toEqual("ConfettiImpact")
		T.expect(CosmeticEffectFactory.effectIdForItem(items, slot, nil)):toBeNil()
		T.expect(CosmeticEffectFactory.effectIdForItem(items, slot, "")):toBeNil()
		T.expect(CosmeticEffectFactory.effectIdForItem(items, slot, "Missing")):toBeNil()
		T.expect(CosmeticEffectFactory.effectIdForItem(items, slot, "BallRed")):toBeNil()
	end)

	T.it("resolves the shipped Confetti Impact against the real catalog", function()
		T.expect(CosmeticEffectFactory.effectIdForItem(Cosmetics.Items, "ImpactEffectAssets", "ConfettiImpact"))
			:toEqual("ConfettiImpact")
	end)

	T.it("registers the production impact collection with unique effect ids", function()
		local seen = {}
		for _, itemId in PRODUCTION_IMPACT_EFFECTS do
			local item = Cosmetics.Items[itemId]
			T.expect(item ~= nil):toBeTruthy()
			T.expect(item.Category):toEqual("ImpactEffectAssets")
			T.expect(Cosmetics.Rarities[item.Rarity] ~= nil):toBeTruthy()
			local effectId = item.EffectId
			assert(effectId ~= nil)
			T.expect(seen[effectId]):toBeNil()
			seen[effectId] = true
		end
	end)

	T.it("lists impact cosmetics in the inventory effects tab", function()
		local found = false
		for _, tab in Inventory.Tabs do
			if tab.Id == "EFFECTS" then
				for _, section in tab.Sections do
					if section.Category == "ImpactEffectAssets" then
						found = true
					end
				end
			end
		end
		T.expect(found):toEqual(true)
	end)

	T.it("lists elimination sounds in the inventory effects tab", function()
		local found = false
		for _, tab in Inventory.Tabs do
			if tab.Id == "EFFECTS" then
				for _, section in tab.Sections do
					if section.Category == "ElimEffectAssets" then
						found = true
					end
				end
			end
		end
		T.expect(found):toEqual(true)
	end)
end)

return true
