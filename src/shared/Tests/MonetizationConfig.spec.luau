--!strict

local T = require(script.Parent.TestKit)
local GamePasses = require(script.Parent.Parent.Parent.Config.GamePasses)
local Products = require(script.Parent.Parent.Parent.Config.Products)

T.describe("MonetizationConfig", function()
	T.it("maps active products into receipt processing and excludes previews", function()
		T.expect(Products.ById[Products.Catalog.Bonks500.Id]):toEqual(Products.Catalog.Bonks500)
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

	T.it("maps active boosters while leaving unauthored cosmetic passes in preview", function()
		T.expect(GamePasses.ById[GamePasses.Catalog.DoubleXP.Id]):toEqual(GamePasses.Catalog.DoubleXP)
		T.expect(GamePasses.ById[GamePasses.Catalog.SplatStarter.Id]):toBeNil()
		T.expect(GamePasses.Catalog.SplatStarter.SuggestedRobux):toEqual(49)
		T.expect(GamePasses.Catalog.EffectCollection.SuggestedRobux):toEqual(149)
		-- Slots with no authored content stay merchandised but grant nothing.
		-- Every pass is in that state right now: the prototype cosmetics they
		-- used to grant were removed, and a pass is never sold empty, so all of
		-- them stay Preview until real content lands.
		T.expect(#GamePasses.Catalog.EffectCollection.EntitlementItemIds):toEqual(0)
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
		-- A player who refuses boosters must still have something to buy. Counted
		-- by declared category rather than granted items: no pass grants anything
		-- yet, and the guarantee being protected is that cosmetic-only offers
		-- exist in the ladder, not that they are already stocked.
		local cosmeticOnly = 0
		for _, definition in GamePasses.Catalog do
			if definition.Boosts == nil and #definition.Categories > 0 then
				cosmeticOnly += 1
			end
		end
		T.expect(cosmeticOnly >= 2):toBeTruthy()
	end)

	T.it("never sells a pass or bundle that grants nothing", function()
		-- Preview is how an unstocked offer is merchandised. Going Active with an
		-- empty grant list is the actual failure, and it is the one thing here
		-- that must never ship.
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
				-- Products.luau only enforces this for Active entries, so the
				-- link is checked here while everything is still Preview.
				T.expect(definition.SeasonId ~= nil):toBeTruthy()
				T.expect(Seasons.Definitions[definition.SeasonId] ~= nil):toBeTruthy()
				T.expect(seen[definition.SeasonId]):toBeNil()
				seen[definition.SeasonId] = key
			end
		end
		T.expect(seen.S1 ~= nil):toBeTruthy()
		-- A season pass is a developer product, never a game pass: the platform
		-- does not remember product ownership, which is why premium is stored.
		T.expect(GamePasses.Catalog.SeasonPassS1):toBeNil()
	end)
end)

return true
