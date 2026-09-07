--!nonstrict

local Modules = game:GetService("ServerScriptService").Server.Modules
local PlayerData = require(Modules.PlayerData)
local CosmeticsService = require(Modules.CosmeticsService)
local FakePlayer = require(script.Parent.Parent.Helpers.FakePlayer)

return function()
	describe("Atomic costume grants", function()
		local player, data
		beforeEach(function()
			player = FakePlayer.new(-773901)
			data = { Cosmetics = { Owned = { FoamLeagueHead = true }, Equipped = {} } }
			PlayerData._profiles[player.UserId] = { Data = data }
		end)
		afterEach(function()
			PlayerData._profiles[player.UserId] = nil
		end)
		it("finishes partial ownership without persisting a second outfit flag", function()
			expect(CosmeticsService.grant(player, "FoamLeague")).to.equal(true)
			expect(data.Cosmetics.Owned.FoamLeague).to.equal(nil)
			expect(data.Cosmetics.Owned.FoamLeagueBody).to.equal(true)
			expect(data.Cosmetics.Owned.FoamLeagueFeet).to.equal(true)
			local granted, reason = CosmeticsService.grant(player, "FoamLeague")
			expect(granted).to.equal(false)
			expect(reason).to.equal("already_owned")
			expect(CosmeticsService.equip(player, "CostumeAssets", "FoamLeague")).to.equal(true)
			expect(player:GetAttribute("Equip_CostumeAssets")).to.equal("FoamLeague")
			expect(CosmeticsService.revokeForTesting(player, "FoamLeagueHead")).to.equal(true)
			expect(player:GetAttribute("Equip_CostumeAssets")).to.equal("")
		end)
	end)
end
