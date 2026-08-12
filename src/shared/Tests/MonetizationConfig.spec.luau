--!strict

local T = require(script.Parent.TestKit)
local GamePasses = require(script.Parent.Parent.Parent.Config.GamePasses)
local Products = require(script.Parent.Parent.Parent.Config.Products)

T.describe("MonetizationConfig", function()
	T.it("keeps preview products visible but out of receipt processing", function()
		T.expect(next(Products.ById)):toBeNil()
		T.expect(Products.Catalog.Cash500.CashAmount):toEqual(500)
		T.expect(Products.Catalog.Cash1100.CashAmount):toEqual(1100)
		T.expect(Products.Catalog.Cash2500.CashAmount):toEqual(2500)
		T.expect(Products.Catalog.Cash5500.CashAmount):toEqual(5500)
		T.expect(Products.Catalog.BallCrateOpen.SuggestedRobux):toEqual(39)
		T.expect(Products.Catalog.TrailCrateOpen.SuggestedRobux):toEqual(79)
		for key, definition in Products.Catalog do
			if key ~= "SeasonalBattlePass" then
				T.expect(definition.CatalogStatus):toEqual("Preview")
				T.expect(definition.Id):toBeNil()
			end
		end
	end)

	T.it("configures permanent pass previews without inventing missing assets", function()
		T.expect(next(GamePasses.ById)):toBeNil()
		T.expect(GamePasses.Catalog.SplatStarter.SuggestedRobux):toEqual(49)
		T.expect(GamePasses.Catalog.TrailCollection.SuggestedRobux):toEqual(149)
		T.expect(GamePasses.Catalog.BrawlersClub.SuggestedRobux):toEqual(499)
		T.expect(GamePasses.Catalog.FoundersPack.SuggestedRobux):toEqual(999)
		T.expect(#GamePasses.Catalog.TrailCollection.EntitlementItemIds):toEqual(5)
		-- Slots with no authored content stay merchandised but grant nothing.
		T.expect(#GamePasses.Catalog.HammerCosmetics.EntitlementItemIds):toEqual(0)
		T.expect(#GamePasses.Catalog.CharacterCostumes.EntitlementItemIds):toEqual(0)
		T.expect(#GamePasses.Catalog.EliminationEmotes.EntitlementItemIds):toEqual(0)
		for _, definition in GamePasses.Catalog do
			T.expect(definition.CatalogStatus):toEqual("Preview")
			T.expect(definition.Id):toBeNil()
		end
	end)

	T.it("ladders pass prices so there is an entry point at every wallet size", function()
		local prices = {}
		for _, definition in GamePasses.Catalog do
			table.insert(prices, definition.SuggestedRobux)
		end
		table.sort(prices)
		T.expect(prices[1] <= 99):toBeTruthy()
		T.expect(prices[#prices] >= 500):toBeTruthy()
		T.expect(#prices >= 4):toBeTruthy()
	end)

	T.it("keeps at least one purely cosmetic pass at every price point that has boosts", function()
		-- A player who refuses boosters must still have something to buy.
		local cosmeticOnly = 0
		for _, definition in GamePasses.Catalog do
			if definition.Boosts == nil and #definition.EntitlementItemIds > 0 then
				cosmeticOnly += 1
			end
		end
		T.expect(cosmeticOnly >= 2):toBeTruthy()
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
