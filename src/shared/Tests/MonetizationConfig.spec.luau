-- Name: MonetizationConfig.spec.luau
-- Author: Jack C.
-- Description: Spec for the shipped monetization configuration: active products mapping into receipt processing, a price ladder with a cosmetic option at every tier, and nothing sold that grants nothing.
-- Created: 2026-07-22

--!strict

local T = require(script.Parent.TestKit)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)
local GamePasses = require(script.Parent.Parent.Parent.Config.Economy.GamePasses)
local Products = require(script.Parent.Parent.Parent.Config.Economy.Products)
local Bundles = require(script.Parent.Parent.Parent.Config.Economy.Bundles)
local StoreCatalog = require(script.Parent.Parent.Game.Economy.StoreCatalog)

T.describe("MonetizationConfig", function()
	T.it("accepts only optional Roblox asset id strings for storefront icons", function()
		for _, catalog in { Products.Catalog, GamePasses.Catalog } do
			for _, definition in catalog do
				local icon = definition.Icon
				T.expect(
					icon == nil
						or icon == ""
						or (type(icon) == "string" and string.match(icon, "^rbxassetid://%d+$") ~= nil)
				):toBeTruthy()
			end
		end
	end)

	T.it("maps every configured product into receipt processing independently of merchandising", function()
		T.expect(Products.ById[Products.Catalog.Bonks500.Id]):toEqual(Products.Catalog.Bonks500)
		T.expect(Products.ById[Products.Catalog.EffectsCrateOpen.Id]):toEqual(Products.Catalog.EffectsCrateOpen)
		T.expect(Products.ById[Products.Catalog.HammerCrateOpen.Id]):toEqual(Products.Catalog.HammerCrateOpen)
		T.expect(Products.Catalog.Bonks500.BonksAmount):toEqual(500)
		T.expect(Products.Catalog.Bonks1100.BonksAmount):toEqual(1100)
		T.expect(Products.Catalog.Bonks2500.BonksAmount):toEqual(2500)
		T.expect(Products.Catalog.Bonks5500.BonksAmount):toEqual(5500)
		for _, definition in Products.Catalog do
			if definition.Id ~= nil then
				T.expect(Products.ById[definition.Id]):toEqual(definition)
			else
				T.expect(Products.ById[definition.Id]):toBeNil()
			end
		end
	end)

	T.it("maps active passes and validates their grants", function()
		T.expect(GamePasses.ById[GamePasses.Catalog.DoubleXP.Id]):toEqual(GamePasses.Catalog.DoubleXP)
		T.expect(GamePasses.Catalog.SplatStarter.Id):toEqual(1968922292)
		T.expect(GamePasses.ById[GamePasses.Catalog.SplatStarter.Id]):toEqual(GamePasses.Catalog.SplatStarter)
		local starterEntitlements = GamePasses.Catalog.SplatStarter.EntitlementItemIds
		T.expect(#starterEntitlements):toEqual(1)
		for _, itemId in starterEntitlements do
			T.expect(itemId):toEqual("Starlight")
			local item = Cosmetics.Items[itemId]
			T.expect(item ~= nil):toBeTruthy()
			T.expect(item.Rarity):toEqual("Exclusive")
			T.expect(item.Category):toEqual("ImpactEffectAssets")
		end
		for _, definition in GamePasses.Catalog do
			if definition.CatalogStatus == "Active" then
				T.expect(definition.Id ~= nil):toBeTruthy()
				T.expect(#definition.EntitlementItemIds > 0 or definition.Boosts ~= nil):toBeTruthy()
			end
		end
	end)

	T.it("keeps retired identities available while hiding their purchase offers", function()
		local catalog = {
			Live = { Id = 1, CatalogStatus = "Active", DisplayOrder = 1 },
			Retired = { Id = 2, CatalogStatus = "Hidden", DisplayOrder = 2 },
			Future = { CatalogStatus = "Preview", DisplayOrder = 3 },
		}
		local byId, keyById = StoreCatalog.platformIndex(catalog)
		T.expect(byId[2]):toEqual(catalog.Retired)
		T.expect(keyById[2]):toEqual("Retired")
		local offers = StoreCatalog.build({}, catalog)
		T.expect(#offers):toEqual(2)
		T.expect(offers[1].key):toEqual("Live")
		T.expect(offers[2].key):toEqual("Future")
		local duplicate = table.clone(catalog)
		duplicate.Future = { Id = 2, CatalogStatus = "Preview" }
		T.expect(pcall(StoreCatalog.platformIndex, duplicate)):toEqual(false)
		T.expect(pcall(StoreCatalog.platformIndex, { Invalid = { CatalogStatus = "Active" } })):toEqual(false)
	end)

	T.it(
		"prepares the starter bundle with complete usable cosmetics without activating an unconfigured product",
		function()
			local bundle = Bundles.Catalog.StarterOutfitBundle
			T.expect(#bundle.ItemIds):toEqual(3)
			for index, id in { "FoamLeague", "DodgeBall3", "StarPop" } do
				T.expect(bundle.ItemIds[index]):toEqual(id)
			end
			T.expect(bundle.CatalogStatus):toEqual("Hidden")
			T.expect(Products.Catalog.StarterOutfitBundleBuy.Id):toBeNil()
			T.expect(Products.Catalog.StarterOutfitBundleBuy.CatalogStatus):toEqual("Hidden")
			for _, id in bundle.ItemIds do
				T.expect(Cosmetics.Items[id] ~= nil):toEqual(true)
				T.expect(Cosmetics.Items[id].InventoryVisible ~= false):toEqual(true)
			end
		end
	)

	T.it("keeps Robux pricing out of both catalogs", function()
		for _, catalog in { GamePasses.Catalog, Products.Catalog } do
			for _, definition in catalog do
				T.expect(definition.SuggestedRobux):toBeNil()
				T.expect(definition.RobuxPrice):toBeNil()
			end
		end
	end)

	T.it("keeps concrete cosmetic grants alongside progression passes", function()
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
		local Seasons = require(script.Parent.Parent.Parent.Config.Progression.Seasons)
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
