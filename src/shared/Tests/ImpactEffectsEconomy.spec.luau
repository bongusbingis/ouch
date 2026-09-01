--!strict

-- Production acquisition contract for impact-effect cosmetics.

local T = require(script.Parent.TestKit)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)
local Crates = require(script.Parent.Parent.Parent.Config.Economy.Crates)
local GamePasses = require(script.Parent.Parent.Parent.Config.Economy.GamePasses)
local Products = require(script.Parent.Parent.Parent.Config.Economy.Products)
local Shop = require(script.Parent.Parent.Parent.Config.Economy.Shop)

local IMPACT_CATEGORY = "ImpactEffectAssets"
local EXCLUSIVE_IDS = { "Prismatic", "Galaxy", "Starlight" }

local function setOf(values: { string }): { [string]: boolean }
	local result = {}
	for _, value in values do
		result[value] = true
	end
	return result
end

T.describe("Impact effect economy", function()
	T.it("activates and merchandises the Effects Crate on both purchase paths", function()
		local crate = Crates.EffectsCrate
		local product = Products.Catalog.EffectsCrateOpen
		T.expect(crate.CatalogStatus):toEqual("Active")
		T.expect(crate.BonksPrice):toEqual(750)
		T.expect(product.CatalogStatus):toEqual("Active")
		T.expect(product.CrateId):toEqual("EffectsCrate")
		T.expect(Products.ById[product.Id]):toEqual(product)

		local featured = false
		for _, entry in Shop.Featured.Rotation do
			if entry.kind == "Crate" and entry.id == "EffectsCrate" then
				featured = true
			end
		end
		T.expect(featured):toEqual(true)
	end)

	T.it("routes every non-exclusive impact to the crate and no exclusive impact into any crate", function()
		local effectsPool = setOf(Crates.EffectsCrate.ItemPool)
		local impactCount = 0
		local crateImpactCount = 0
		for itemId, item in Cosmetics.Items do
			if item.Category == IMPACT_CATEGORY then
				impactCount += 1
				T.expect(item.EffectId):toEqual(itemId)
				if item.Rarity == "Exclusive" then
					T.expect(effectsPool[itemId]):toBeNil()
				else
					crateImpactCount += 1
					T.expect(effectsPool[itemId]):toEqual(true)
				end
			end
		end
		T.expect(impactCount):toEqual(13)
		T.expect(crateImpactCount):toEqual(10)

		for _, crate in Crates do
			for _, itemId in crate.ItemPool do
				T.expect(Cosmetics.Items[itemId].Rarity ~= "Exclusive"):toBeTruthy()
			end
		end
	end)

	T.it("routes exactly the exclusive impact collection through its preview pass", function()
		local pass = GamePasses.Catalog.EffectCollection
		T.expect(pass.CatalogStatus):toEqual("Preview")
		T.expect(pass.Id):toBeNil()
		T.expect(#pass.EntitlementItemIds):toEqual(#EXCLUSIVE_IDS)
		for index, itemId in pass.EntitlementItemIds do
			T.expect(itemId):toEqual(EXCLUSIVE_IDS[index])
		end

		local granted = setOf(pass.EntitlementItemIds)
		local exclusiveCount = 0
		for itemId, item in Cosmetics.Items do
			if item.Category == IMPACT_CATEGORY and item.Rarity == "Exclusive" then
				exclusiveCount += 1
				T.expect(granted[itemId]):toEqual(true)
			end
		end
		T.expect(exclusiveCount):toEqual(3)
	end)
end)

return true
