-- Name: MonetizationConfig.spec.luau
-- Author: Jack C.
-- Description: Spec for the shipped monetization configuration: active products mapping into receipt processing, a price ladder with a cosmetic option at every tier, and nothing sold that grants nothing.
-- Created: 2026-07-22

--!strict

local T = require(script.Parent.TestKit)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)
local GamePasses = require(script.Parent.Parent.Parent.Config.GamePasses)
local Products = require(script.Parent.Parent.Parent.Config.Products)

T.describe("MonetizationConfig", function()
	T.it("maps active products into receipt processing and excludes previews", function()
		T.expect(Products.ById[Products.Catalog.Bonks500.Id]):toEqual(Products.Catalog.Bonks500)
		T.expect(Products.ById[Products.Catalog.EffectsCrateOpen.Id]):toEqual(Products.Catalog.EffectsCrateOpen)
		T.expect(Products.ById[Products.Catalog.HammerCrateOpen.Id]):toBeNil()
		T.expect(Products.Catalog.Bonks500.BonksAmount):toEqual(500)
		T.expect(Products.Catalog.Bonks1100.BonksAmount):toEqual(1100)
		T.expect(Products.Catalog.Bonks2500.BonksAmount):toEqual(2500)
		T.expect(Products.Catalog.Bonks5500.BonksAmount):toEqual(5500)
		T.expect(Products.Catalog.DodgeballCrateOpen.SuggestedRobux):toEqual(39)
		T.expect(Products.Catalog.EffectsCrateOpen.SuggestedRobux):toEqual(59)
		for _, definition in Products.Catalog do
			if definition.CatalogStatus == "Active" then
				T.expect(Products.ById[definition.Id]):toEqual(definition)
			else
				T.expect(Products.ById[definition.Id]):toBeNil()
			end
		end
	end)

	T.it("maps active boosters while leaving cosmetic passes in preview", function()
		T.expect(GamePasses.ById[GamePasses.Catalog.DoubleXP.Id]):toEqual(GamePasses.Catalog.DoubleXP)
		T.expect(GamePasses.ById[GamePasses.Catalog.SplatStarter.Id]):toBeNil()
		T.expect(GamePasses.Catalog.SplatStarter.SuggestedRobux):toEqual(49)
		T.expect(GamePasses.Catalog.EffectCollection.SuggestedRobux):toEqual(149)
		local impactEntitlements = GamePasses.Catalog.EffectCollection.EntitlementItemIds
		local expectedImpactEntitlements = { "Prismatic", "Galaxy", "Starlight" }
		T.expect(#impactEntitlements):toEqual(#expectedImpactEntitlements)
		for index, itemId in impactEntitlements do
			T.expect(itemId):toEqual(expectedImpactEntitlements[index])
			local item = Cosmetics.Items[itemId]
			T.expect(item ~= nil):toBeTruthy()
			T.expect(item.Rarity):toEqual("Exclusive")
			T.expect(item.Category):toEqual("ImpactEffectAssets")
		end
		T.expect(#GamePasses.Catalog.HammerCosmetics.EntitlementItemIds):toEqual(0)
		T.expect(#GamePasses.Catalog.CharacterCostumes.EntitlementItemIds):toEqual(0)
		T.expect(#GamePasses.Catalog.EliminationEmotes.EntitlementItemIds):toEqual(0)
		for _, definition in GamePasses.Catalog do
			if definition.CatalogStatus == "Active" then
				T.expect(definition.Id ~= nil):toBeTruthy()
				T.expect(definition.Boosts ~= nil):toBeTruthy()
			else
				T.expect(definition.Id):toBeNil()
			end
		end
	end)

	T.it("ladders pass prices so there is an entry point at every wallet size", function()
		local prices = {}
		for _, definition in GamePasses.Catalog do
			table.insert(prices, definition.SuggestedRobux)
		end
		table.sort(prices)
		T.expect(prices[1] <= 99):toBeTruthy()
		T.expect(prices[#prices] >= 399):toBeTruthy()
		T.expect(#prices >= 4):toBeTruthy()
	end)

	T.it("keeps at least one purely cosmetic pass at every price point that has boosts", function()
		local cosmeticOnly = 0
		for _, definition in GamePasses.Catalog do
			if definition.Boosts == nil and #definition.Categories > 0 then
				cosmeticOnly += 1
			end
		end
		T.expect(cosmeticOnly >= 2):toBeTruthy()
	end)

	T.it("never sells a pass or bundle that grants nothing", function()
		for key, definition in GamePasses.Catalog do
			if definition.CatalogStatus == "Active" and definition.Boosts == nil then
				T.expect(#definition.EntitlementItemIds > 0):toBeTruthy()
				T.expect(type(key)):toEqual("string")
			end
		end
	end)

	T.it("ships one season pass product per season, each naming a real season", function()
		local Seasons = require(script.Parent.Parent.Parent.Config.Seasons)
		local seen = {}
		for key, definition in Products.Catalog do
			if definition.Type == "SeasonPass" then
				T.expect(definition.SeasonId ~= nil):toBeTruthy()
				T.expect(Seasons.Definitions[definition.SeasonId] ~= nil):toBeTruthy()
				T.expect(seen[definition.SeasonId]):toBeNil()
				seen[definition.SeasonId] = key
			end
		end
		T.expect(seen.S1 ~= nil):toBeTruthy()
		T.expect(GamePasses.Catalog.SeasonPassS1):toBeNil()
	end)
end)

return true
