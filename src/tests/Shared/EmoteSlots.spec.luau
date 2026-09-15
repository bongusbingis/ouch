-- Name: EmoteSlots.spec.luau
-- Author: Jack C.
-- Description: Covers CosmeticsService.setEmoteSlot move/clear/reject semantics and the PlayerData migration that seeds slot 1 from a legacy single-equip emote.
-- Created: 2026-09-09

--!nonstrict

local Modules = game:GetService("ServerScriptService").Server.Modules
local PlayerData = require(Modules.PlayerData)
local CosmeticsService = require(Modules.CosmeticsService)
local EntitlementService = require(Modules.EntitlementService)
local FakePlayer = require(script.Parent.Parent.Helpers.FakePlayer)

return function()
	describe("Emote slots", function()
		local player, data
		beforeEach(function()
			EntitlementService._resetForTest()
			player = FakePlayer.new(-773905)
			data = {
				Cosmetics = {
					Owned = { ShowtimeTwirl = true },
					Equipped = {},
					EmoteSlots = {},
				},
			}
			PlayerData._profiles[player.UserId] = { Data = data }
		end)
		afterEach(function()
			PlayerData._profiles[player.UserId] = nil
			EntitlementService._resetForTest()
		end)

		it("assigns an owned emote to slot 1", function()
			expect(CosmeticsService.setEmoteSlot(player, 1, "ShowtimeTwirl")).to.equal(true)
			expect(data.Cosmetics.EmoteSlots[1]).to.equal("ShowtimeTwirl")
		end)

		it("moves an equipped emote to its new slot, clearing the old one", function()
			expect(CosmeticsService.setEmoteSlot(player, 1, "ShowtimeTwirl")).to.equal(true)
			expect(CosmeticsService.setEmoteSlot(player, 3, "ShowtimeTwirl")).to.equal(true)
			expect(data.Cosmetics.EmoteSlots[3]).to.equal("ShowtimeTwirl")
			expect(data.Cosmetics.EmoteSlots[1]).to.equal("")
		end)

		it("clears a slot", function()
			CosmeticsService.setEmoteSlot(player, 1, "ShowtimeTwirl")
			expect(CosmeticsService.setEmoteSlot(player, 1, nil)).to.equal(true)
			expect(data.Cosmetics.EmoteSlots[1]).to.equal("")
		end)

		it("rejects an unowned emote", function()
			local ok, reason = CosmeticsService.setEmoteSlot(player, 1, "ShowtimeFlex")
			expect(ok).to.equal(false)
			expect(reason).to.equal("not_owned")
		end)

		it("rejects a non-emote item", function()
			local ok, reason = CosmeticsService.setEmoteSlot(player, 1, "CharacterColorRed")
			expect(ok).to.equal(false)
			expect(reason).to.equal("not_emote")
		end)

		it("rejects slot 5 when capacity is 4", function()
			local ok, reason = CosmeticsService.setEmoteSlot(player, 5, "ShowtimeTwirl")
			expect(ok).to.equal(false)
			expect(reason).to.equal("bad_slot")
		end)

		it("opens slots 5-8 once the Showtime pass is owned", function()
			EntitlementService.setOwnership(player, "Showtime", true)
			expect(CosmeticsService.setEmoteSlot(player, 5, "ShowtimeTwirl")).to.equal(true)
			expect(CosmeticsService.setEmoteSlot(player, 8, "ShowtimeTwirl")).to.equal(true)
			expect(data.Cosmetics.EmoteSlots[8]).to.equal("ShowtimeTwirl")
			expect(data.Cosmetics.EmoteSlots[5]).to.equal("")
			local ok, reason = CosmeticsService.setEmoteSlot(player, 9, "ShowtimeTwirl")
			expect(ok).to.equal(false)
			expect(reason).to.equal("bad_slot")
		end)

		it("publishes the wheel capacity attribute when entitlements refresh", function()
			CosmeticsService.refreshEquipAttributes(player)
			expect(player:GetAttribute("EmoteSlotCapacity")).to.equal(4)
			EntitlementService.setOwnership(player, "Showtime", true)
			CosmeticsService.refreshEquipAttributes(player)
			expect(player:GetAttribute("EmoteSlotCapacity")).to.equal(8)
			expect(player:GetAttribute("EmoteSlot_1")).to.equal("")
		end)

		it("migration seeds slot 1 from a legacy Equipped.EmoteAssets string", function()
			local legacy = { Cosmetics = { Owned = {}, Equipped = { EmoteAssets = "ShowtimeTwirl" } } }
			PlayerData._migrateEmoteSlots(legacy)
			expect(legacy.Cosmetics.EmoteSlots[1]).to.equal("ShowtimeTwirl")
			expect(legacy.Cosmetics.Equipped.EmoteAssets).to.equal(nil)
		end)
	end)
end
