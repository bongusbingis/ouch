-- Name: Emotes.spec.luau
-- Author: Jack C.
-- Description: Covers the emote catalog shape -- the free Wave default, the three Showtime clips, and that they stay out of crate pools -- through the existing locker and equip rules.
-- Created: 2026-09-09

--!strict

local T = require(script.Parent.TestKit)
local Emotes = require(script.Parent.Parent.Parent.Config.Cosmetics.Emotes)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)
local Passes = require(script.Parent.Parent.Parent.Config.Economy.GamePasses)
local Crates = require(script.Parent.Parent.Parent.Config.Economy.Crates)
local InventoryModel = require(script.Parent.Parent.Game.Economy.InventoryModel)
local CosmeticsLogic = require(script.Parent.Parent.Game.Economy.CosmeticsLogic)

T.describe("Victory emotes", function()
	T.it("takes a granted collection through the existing locker and equip rules", function()
		local free = InventoryModel.entries(Cosmetics, {}, "EmoteAssets")
		T.expect(#free):toEqual(2)
		T.expect(InventoryModel.isEquipped(free[1], {})):toBeTruthy()
		T.expect(CosmeticsLogic.canEquip(Cosmetics.Items, Cosmetics.Slots, {}, "EmoteAssets", "ShowtimeTwirl"))
			:toEqual(false)
		local owned = {}
		for _, id in Passes.Catalog.Showtime.EntitlementItemIds do
			owned[id] = true
		end
		local entries = InventoryModel.entries(Cosmetics, owned, "EmoteAssets")
		T.expect(#entries):toEqual(5)
		local equipped = {}
		for _, entry in entries do
			local id = InventoryModel.nextEquip(entry, equipped)
			T.expect(CosmeticsLogic.canEquip(Cosmetics.Items, Cosmetics.Slots, owned, "EmoteAssets", id)):toBeTruthy()
			equipped.EmoteAssets = id
			T.expect(InventoryModel.isEquipped(entry, equipped)):toBeTruthy()
		end
		T.expect(InventoryModel.nextEquip(free[1], equipped)):toBeNil()
	end)
	T.it("grants the three advertised Showtime emotes on top of the free Wave default", function()
		local pass = Passes.Catalog.Showtime
		T.expect(pass.Id):toEqual(1970065084)
		T.expect(pass.Boosts):toBeNil()
		T.expect(pass.EmoteSlots):toEqual(8)
		T.expect(#pass.EntitlementItemIds):toEqual(3)
		T.expect(Cosmetics.Slots.EmoteAssets):toBeTruthy()
		local seen = {}
		for _, id in pass.EntitlementItemIds do
			local item = Cosmetics.Items[id]
			T.expect(item.Category):toEqual("EmoteAssets")
			T.expect(item.Rarity):toEqual("Exclusive")
			T.expect(item.ShopEligible):toEqual(false)
			T.expect(Emotes.Clips[id] ~= nil):toBeTruthy()
			T.expect(seen[id]):toBeNil()
			seen[id] = true
		end
		T.expect(Cosmetics.Items.EmoteWave.Category):toEqual("EmoteAssets")
		T.expect(Cosmetics.Items.EmoteWave.AlwaysAvailable):toEqual(true)
		T.expect(Emotes.Clips.EmoteWave ~= nil):toBeTruthy()
		T.expect(Cosmetics.Defaults.EmoteAssets.DisplayName):toEqual("Wave")
	end)
	T.it("keeps paid victory emotes out of random crate pools", function()
		for _, crateId in { "DodgeballCrate", "HammerCrate", "EffectsCrate" } do
			for _, id in Crates[crateId].ItemPool do
				T.expect(Cosmetics.Items[id].Category == "EmoteAssets"):toEqual(false)
			end
		end
	end)
end)

return true
