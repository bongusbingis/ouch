--!strict

local T = require(script.Parent.TestKit)
local GamePasses = require(script.Parent.Parent.Parent.Config.GamePasses)
local Products = require(script.Parent.Parent.Parent.Config.Products)

T.describe("MonetizationConfig", function()
	T.it("keeps developer-product stubs out of receipt processing", function()
		T.expect(next(Products.ById)):toBeNil()
		for _, definition in Products.Catalog do
			T.expect(definition.Enabled):toEqual(false)
			T.expect(definition.Id):toBeNil()
			T.expect(type(definition.DisplayOrder)):toEqual("number")
		end
	end)

	T.it("keeps GDD game-pass stubs disabled until entitlements exist", function()
		T.expect(next(GamePasses.ById)):toBeNil()
		T.expect(GamePasses.Catalog.HammerCosmetics.SuggestedRobuxMin):toEqual(150)
		T.expect(GamePasses.Catalog.DodgeballEffects.SuggestedRobuxMax):toEqual(250)
		T.expect(GamePasses.Catalog.CharacterCostumes.SuggestedRobuxMax):toEqual(600)
		T.expect(GamePasses.Catalog.EliminationEmotes.SuggestedRobuxMin):toEqual(75)

		for _, definition in GamePasses.Catalog do
			T.expect(definition.Enabled):toEqual(false)
			T.expect(definition.Id):toBeNil()
			T.expect(#definition.EntitlementItemIds):toEqual(0)
			T.expect(type(definition.DisplayOrder)):toEqual("number")
			T.expect(definition.SuggestedRobuxMin <= definition.SuggestedRobuxMax):toBeTruthy()
		end
	end)

	T.it("models the resetting battle pass as a developer product", function()
		local battlePass = Products.Catalog.SeasonalBattlePass
		T.expect(battlePass.Type):toEqual("SeasonPass")
		T.expect(battlePass.SuggestedRobux):toEqual(799)
		T.expect(GamePasses.Catalog.SeasonalBattlePass):toBeNil()
	end)
end)

return true
