-- Description: Spec for the per-player shop draw: determinism per player and period, exclusion of owned items, distinct results, pool edge cases, and why the drawn set must be persisted.

--!strict

local T = require(script.Parent.TestKit)
local ShopRotation = require(script.Parent.Parent.Game.Economy.ShopRotation)
local CosmeticsLogic = require(script.Parent.Parent.Game.Economy.CosmeticsLogic)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)
local Shop = require(script.Parent.Parent.Parent.Config.Economy.Shop)
local Bundles = require(script.Parent.Parent.Parent.Config.Economy.Bundles)

local POOL = { "ItemA", "ItemB", "ItemC", "ItemD", "ItemE", "ItemF" }

local function contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

T.describe("ShopRotation", function()
	T.it("draws the same offers for the same player and period", function()
		local first = ShopRotation.draw(12345, 900, POOL, {}, 3)
		local second = ShopRotation.draw(12345, 900, POOL, {}, 3)
		T.expect(table.concat(first, ",")):toEqual(table.concat(second, ","))
	end)

	T.it("draws different offers for different players in the same period", function()
		local differs = false
		local reference = table.concat(ShopRotation.draw(1, 900, POOL, {}, 3), ",")
		for userId = 2, 12 do
			if table.concat(ShopRotation.draw(userId, 900, POOL, {}, 3), ",") ~= reference then
				differs = true
				break
			end
		end
		T.expect(differs):toBeTruthy()
	end)

	T.it("draws different offers for the same player across periods", function()
		local differs = false
		local reference = table.concat(ShopRotation.draw(777, 100, POOL, {}, 3), ",")
		for period = 101, 111 do
			if table.concat(ShopRotation.draw(777, period, POOL, {}, 3), ",") ~= reference then
				differs = true
				break
			end
		end
		T.expect(differs):toBeTruthy()
	end)

	T.it("never offers an item the player already owns", function()
		local owned = { ItemA = true, ItemC = true, ItemE = true }
		for userId = 1, 40 do
			for _, itemId in ShopRotation.draw(userId, 5, POOL, owned, 3) do
				T.expect(owned[itemId] ~= true):toBeTruthy()
			end
		end
	end)

	T.it("returns distinct items within one draw", function()
		for userId = 1, 40 do
			local seen = {}
			for _, itemId in ShopRotation.draw(userId, 7, POOL, {}, 4) do
				T.expect(seen[itemId]):toBeNil()
				seen[itemId] = true
			end
		end
	end)

	T.it("returns the whole pool rather than erroring when it is smaller than the count", function()
		local drawn = ShopRotation.draw(42, 3, { "Only" }, {}, 3)
		T.expect(#drawn):toEqual(1)
		T.expect(drawn[1]):toEqual("Only")
	end)

	T.it("returns nothing when the pool is empty", function()
		T.expect(#ShopRotation.draw(42, 3, {}, {}, 3)):toEqual(0)
	end)

	T.it("returns nothing when the player owns everything", function()
		local owned = {}
		for _, itemId in POOL do
			owned[itemId] = true
		end
		T.expect(#ShopRotation.draw(42, 3, POOL, owned, 3)):toEqual(0)
	end)

	T.it("ignores the caller's pool ordering", function()
		local reversed = {}
		for index = #POOL, 1, -1 do
			table.insert(reversed, POOL[index])
		end
		local straight = ShopRotation.draw(9001, 12, POOL, {}, 3)
		local shuffled = ShopRotation.draw(9001, 12, reversed, {}, 3)
		T.expect(table.concat(straight, ",")):toEqual(table.concat(shuffled, ","))
	end)

	T.it("drops the bought item from a redraw, which is why the set is persisted", function()
		local drawn = ShopRotation.draw(555, 21, POOL, {}, 3)
		T.expect(#drawn):toEqual(3)
		local redrawn = ShopRotation.draw(555, 21, POOL, { [drawn[1]] = true }, 3)
		T.expect(contains(redrawn, drawn[1])):toEqual(false)
	end)

	T.it("can reshuffle offers the player did not buy, so a redraw is not idempotent", function()
		local drifted = false
		for userId = 1, 60 do
			local drawn = ShopRotation.draw(userId, 21, POOL, {}, 3)
			if #drawn == 3 then
				local redrawn = ShopRotation.draw(userId, 21, POOL, { [drawn[1]] = true }, 3)
				if not contains(redrawn, drawn[2]) or not contains(redrawn, drawn[3]) then
					drifted = true
					break
				end
			end
		end
		T.expect(drifted):toBeTruthy()
	end)

	T.it("stays inside 2^53 so every platform agrees on the same draw", function()
		for userId = 1, 200 do
			for _, itemId in ShopRotation.draw(userId * 1000003, 4321, POOL, {}, 3) do
				T.expect(contains(POOL, itemId)):toBeTruthy()
			end
		end
	end)

	T.it("builds its pool from the configured categories and skips free items", function()
		local pool = ShopRotation.pool(Cosmetics.Items, Shop.Rotation.Categories)
		for _, itemId in pool do
			local item = Cosmetics.Items[itemId]
			T.expect(table.find(Shop.Rotation.Categories, item.Category) ~= nil):toBeTruthy()
			T.expect(item.AlwaysAvailable ~= true):toBeTruthy()
		end
	end)

	T.it("never offers a character color, which every player already has for free", function()
		local pool = ShopRotation.pool(Cosmetics.Items, { "CharacterColor" })
		T.expect(#pool):toEqual(0)
	end)

	T.it("ships a rotation whose categories are real equip slots", function()
		for _, category in Shop.Rotation.Categories do
			T.expect(Cosmetics.Slots[category]):toEqual(true)
		end
		T.expect(table.find(Shop.Rotation.Categories, "EmoteAssets")):toBeNil()
	end)

	T.it("fills the three named roles deterministically with distinct items", function()
		local pools = ShopRotation.poolByRarity(Cosmetics.Items, Shop.Rotation.Categories)
		for userId = 1, 40 do
			for bucket = 1, 10 do
				local offers = ShopRotation.drawRoles(userId, bucket, pools, {}, Shop.Rotation.Roles, Cosmetics.Items)
				local repeatDraw =
					ShopRotation.drawRoles(userId, bucket, pools, {}, Shop.Rotation.Roles, Cosmetics.Items)
				T.expect(#offers):toEqual(3)
				local seen = {}
				local byRole = {}
				for index, offer in offers do
					T.expect(offer.ItemId):toEqual(repeatDraw[index].ItemId)
					T.expect(offer.Role):toEqual(repeatDraw[index].Role)
					T.expect(seen[offer.ItemId]):toBeNil()
					seen[offer.ItemId] = true
					byRole[offer.Role] = offer
				end
				T.expect(byRole.RobuxCommon.Rarity):toEqual("Common")
				T.expect(byRole.RobuxPremium.Rarity == "Rare" or byRole.RobuxPremium.Rarity == "Legendary")
					:toBeTruthy()
				T.expect(byRole.Bonks ~= nil):toBeTruthy()
			end
		end
	end)

	T.it("uses the configured 70/30 premium rarity mix", function()
		local premium = Shop.Rotation.Roles[2]
		T.expect(premium.Id):toEqual("RobuxPremium")
		T.expect(premium.Rarities[1]):toEqual("Rare")
		T.expect(premium.Rarities[2]):toEqual("Legendary")
		T.expect(premium.Weights[1]):toEqual(70)
		T.expect(premium.Weights[2]):toEqual(30)
	end)

	T.it("omits an exhausted Common role without changing either remaining role", function()
		local pools = ShopRotation.poolByRarity(Cosmetics.Items, Shop.Rotation.Categories)
		local owned = {}
		for _, itemId in pools.Common do
			for _, grantId in CosmeticsLogic.grantIds(Cosmetics.Items, itemId) do
				owned[grantId] = true
			end
		end
		local offers = ShopRotation.drawRoles(123, 456, pools, owned, Shop.Rotation.Roles, Cosmetics.Items)
		T.expect(#offers):toEqual(2)
		T.expect(offers[1].Role):toEqual("RobuxPremium")
		T.expect(offers[2].Role):toEqual("Bonks")
	end)

	T.it("ships a bundle rotation naming only bundles that exist", function()
		for _, entry in Shop.Bundle.Rotation do
			T.expect(entry.kind):toEqual("Bundle")
			T.expect(Bundles.Catalog[entry.id] ~= nil):toBeTruthy()
		end
	end)
end)

return true
