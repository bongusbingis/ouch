-- Name: CrateBatch.spec.luau
-- Author: Jack C.
-- Description: Spec for the bulk crate-open rules: which quantities a crate offers, rejection of quantities outside that set or outside the hard cap, straight-multiple pricing with no volume discount, and best-rarity selection for the reveal summary.
-- Created: 2026-08-25

--!strict

local T = require(script.Parent.TestKit)
local CrateBatch = require(script.Parent.Parent.Game.Economy.CrateBatch)
local Crates = require(script.Parent.Parent.Parent.Config.Economy.Crates)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)

local BULK = { OpenQuantities = { 1, 5, 10 } }

T.describe("CrateBatch", function()
	T.it("falls back to single opens for a crate that declares no quantities", function()
		T.expect(#CrateBatch.quantitiesFor(nil)):toEqual(1)
		T.expect(CrateBatch.quantitiesFor(nil)[1]):toEqual(1)
		T.expect(CrateBatch.quantitiesFor({})[1]):toEqual(1)
		T.expect(CrateBatch.quantitiesFor({ OpenQuantities = {} })[1]):toEqual(1)
	end)

	T.it("accepts only the quantities a crate actually offers", function()
		T.expect(CrateBatch.isValidQuantity(BULK, 1)):toEqual(true)
		T.expect(CrateBatch.isValidQuantity(BULK, 5)):toEqual(true)
		T.expect(CrateBatch.isValidQuantity(BULK, 10)):toEqual(true)
		T.expect(CrateBatch.isValidQuantity(BULK, 2)):toEqual(false)
		T.expect(CrateBatch.isValidQuantity(BULK, 3)):toEqual(false)
	end)

	T.it("rejects quantities that are not positive whole numbers", function()
		T.expect(CrateBatch.isValidQuantity(BULK, 0)):toEqual(false)
		T.expect(CrateBatch.isValidQuantity(BULK, -5)):toEqual(false)
		T.expect(CrateBatch.isValidQuantity(BULK, 1.5)):toEqual(false)
		T.expect(CrateBatch.isValidQuantity(BULK, "5")):toEqual(false)
		T.expect(CrateBatch.isValidQuantity(BULK, nil)):toEqual(false)
		T.expect(CrateBatch.isValidQuantity(BULK, 0 / 0)):toEqual(false)
	end)

	T.it("never admits a quantity beyond the hard cap even if a crate declares one", function()
		local oversized = { OpenQuantities = { 1, CrateBatch.HardMaximum + 1 } }
		T.expect(CrateBatch.isValidQuantity(oversized, CrateBatch.HardMaximum + 1)):toEqual(false)
		T.expect(CrateBatch.isValidQuantity(oversized, 1)):toEqual(true)
	end)

	T.it("charges a straight multiple, with no volume discount", function()
		T.expect(CrateBatch.totalPrice(500, 1)):toEqual(500)
		T.expect(CrateBatch.totalPrice(500, 5)):toEqual(2500)
		T.expect(CrateBatch.totalPrice(500, 10)):toEqual(5000)
		T.expect(CrateBatch.totalPrice(750, 10)):toEqual(7500)
	end)

	T.it("picks the rarest pull in a batch for the reveal headline", function()
		local rarities = Cosmetics.Rarities
		local batch = {
			{ rarity = "Common" },
			{ rarity = "Legendary" },
			{ rarity = "Rare" },
			{ rarity = "Common" },
		}
		T.expect(CrateBatch.bestRarity(batch, rarities)):toEqual("Legendary")
		T.expect(CrateBatch.bestRarity({ { rarity = "Common" } }, rarities)):toEqual("Common")
		T.expect(CrateBatch.bestRarity({}, rarities)):toBeNil()
		T.expect(CrateBatch.bestRarity({ { rarity = "NotARarity" } }, rarities)):toBeNil()
	end)

	T.it("offers a single open first for every shipped crate that offers bulk", function()
		for crateId, crate in Crates do
			local quantities = CrateBatch.quantitiesFor(crate)
			T.expect(quantities[1] == 1):toBeTruthy()
			T.expect(CrateBatch.isValidQuantity(crate, 1)):toBeTruthy()
			for _, quantity in quantities do
				T.expect(quantity <= CrateBatch.HardMaximum):toBeTruthy()
				T.expect(CrateBatch.isValidQuantity(crate, quantity)):toBeTruthy()
			end
			T.expect(typeof(crateId)):toEqual("string")
		end
	end)

	T.it("keeps every shipped bulk price an exact multiple of the single-open price", function()
		for _, crate in Crates do
			if crate.BonksPrice == nil then
				continue
			end
			for _, quantity in CrateBatch.quantitiesFor(crate) do
				local total = CrateBatch.totalPrice(crate.BonksPrice, quantity)
				T.expect(total % crate.BonksPrice):toEqual(0)
				T.expect(total // crate.BonksPrice):toEqual(quantity)
			end
		end
	end)
end)

return true
