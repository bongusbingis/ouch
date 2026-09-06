--!strict

local T = require(script.Parent.TestKit)
local Pose = require(script.Parent.Parent.Game.Cosmetics.VictoryPose)
local Emotes = require(script.Parent.Parent.Parent.Config.Cosmetics.Emotes)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics.Cosmetics)
local Passes = require(script.Parent.Parent.Parent.Config.Economy.GamePasses)
local Crates = require(script.Parent.Parent.Parent.Config.Economy.Crates)
local InventoryModel = require(script.Parent.Parent.Game.Economy.InventoryModel)
local CosmeticsLogic = require(script.Parent.Parent.Game.Economy.CosmeticsLogic)

T.describe("Victory emotes", function()
	T.it("takes a granted collection through the existing locker and equip rules", function()
		local free = InventoryModel.entries(Cosmetics, {}, "EmoteAssets")
		T.expect(#free):toEqual(1)
		T.expect(InventoryModel.isEquipped(free[1], {})):toBeTruthy()
		T.expect(CosmeticsLogic.canEquip(Cosmetics.Items, Cosmetics.Slots, {}, "EmoteAssets", "ShowtimeTwirl"))
			:toEqual(false)
		local owned = {}
		for _, id in Passes.Catalog.Showtime.EntitlementItemIds do
			owned[id] = true
		end
		local entries = InventoryModel.entries(Cosmetics, owned, "EmoteAssets")
		T.expect(#entries):toEqual(4)
		local equipped = {}
		for _, entry in entries do
			local id = InventoryModel.nextEquip(entry, equipped)
			T.expect(CosmeticsLogic.canEquip(Cosmetics.Items, Cosmetics.Slots, owned, "EmoteAssets", id)):toBeTruthy()
			equipped.EmoteAssets = id
			T.expect(InventoryModel.isEquipped(entry, equipped)):toBeTruthy()
		end
		T.expect(InventoryModel.nextEquip(free[1], equipped)):toBeNil()
	end)
	T.it("uses the existing emote slot and grants the three advertised styles", function()
		local pass = Passes.Catalog.Showtime
		T.expect(pass.Id):toEqual(1970065084)
		T.expect(pass.Boosts):toBeNil()
		T.expect(#pass.EntitlementItemIds):toEqual(3)
		T.expect(Cosmetics.Slots.EmoteAssets):toBeTruthy()
		local styles = {}
		for _, id in pass.EntitlementItemIds do
			local item = Cosmetics.Items[id]
			T.expect(item.Category):toEqual("EmoteAssets")
			T.expect(item.Rarity):toEqual("Exclusive")
			T.expect(item.ShopEligible):toEqual(false)
			T.expect(Emotes.Styles[item.EmoteStyle] ~= nil):toBeTruthy()
			T.expect(styles[item.EmoteStyle]):toBeNil()
			styles[item.EmoteStyle] = true
		end
		T.expect(Cosmetics.Defaults.EmoteAssets.EmoteStyle):toEqual(Emotes.DefaultStyle)
	end)
	T.it("keeps paid victory emotes out of random crate pools", function()
		for _, crateId in { "DodgeballCrate", "HammerCrate", "EffectsCrate" } do
			for _, id in Crates[crateId].ItemPool do
				T.expect(Cosmetics.Items[id].Category == "EmoteAssets"):toEqual(false)
			end
		end
	end)
	T.it("loops without growing the pose and holds a fixed reduced-motion pose", function()
		for _, style in Emotes.Styles do
			local a = Pose.sample(style.Pose, 0.37, style.Duration)
			local b = Pose.sample(style.Pose, 0.37 + style.Duration, style.Duration)
			local stillA = Pose.sample(style.Pose, 0, style.Duration, true)
			local stillB = Pose.sample(style.Pose, 100, style.Duration, true)
			for key, value in a do
				T.expect(value == value and math.abs(value) < 10):toBeTruthy()
				T.expect(value):toBeNear(b[key], 0.00001)
				T.expect(stillA[key]):toEqual(stillB[key])
			end
		end
	end)
end)

return true
