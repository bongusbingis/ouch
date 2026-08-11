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
		T.expect(GamePasses.Catalog.HammerCosmetics.SuggestedRobux):toEqual(249)
		T.expect(GamePasses.Catalog.DodgeballEffects.SuggestedRobux):toEqual(149)
		T.expect(GamePasses.Catalog.CharacterCostumes.SuggestedRobux):toEqual(399)
		T.expect(GamePasses.Catalog.EliminationEmotes.SuggestedRobux):toEqual(99)
		T.expect(#GamePasses.Catalog.DodgeballEffects.EntitlementItemIds):toEqual(5)
		T.expect(#GamePasses.Catalog.HammerCosmetics.EntitlementItemIds):toEqual(0)
		T.expect(#GamePasses.Catalog.CharacterCostumes.EntitlementItemIds):toEqual(0)
		T.expect(#GamePasses.Catalog.EliminationEmotes.EntitlementItemIds):toEqual(0)
		for _, definition in GamePasses.Catalog do
			T.expect(definition.CatalogStatus):toEqual("Preview")
			T.expect(definition.Id):toBeNil()
		end
	end)

	T.it("keeps the seasonal battle pass hidden", function()
		local battlePass = Products.Catalog.SeasonalBattlePass
		T.expect(battlePass.Type):toEqual("SeasonPass")
		T.expect(battlePass.CatalogStatus):toEqual("Hidden")
		T.expect(GamePasses.Catalog.SeasonalBattlePass):toBeNil()
	end)
end)

return true
