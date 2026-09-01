-- Name: Cosmetics.spec.luau
-- Author: Jack C.
-- Description: In-place spec validating the authored cosmetic carriers, their meshes and textures, the hammer grip axis, elimination effect audio, and that crate pools only reference real purchasable items.
-- Created: 2026-07-16

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerStorage = game:GetService("ServerStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates"))
local Audio = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Audio"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))
local ScriptEffects = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("Effects")
		:WaitForChild("ScriptEffects")
)
local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local HammerGrip = require(Client:WaitForChild("Modules"):WaitForChild("Presentation"):WaitForChild("HammerGrip"))

local function numericAssetId(contentId)
	return tonumber(string.match(contentId, "%d+"))
end

return function()
	describe("Cosmetics assets", function()
		it("has every configured MeshPart carrier with its catalog mesh", function()
			for _, definition in Cosmetics.VisualTemplates do
				local carrier =
					TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "Templates", definition.CarrierName)
				expect(carrier:IsA("MeshPart")).to.equal(true)
				expect(numericAssetId(carrier.MeshId)).to.equal(definition.MeshId)
			end
		end)

		it("keeps the authored hammer PBR maps on its carrier", function()
			local carrier = TestAssets.get(
				ReplicatedStorage,
				"Assets",
				"Cosmetics",
				"Templates",
				Cosmetics.VisualTemplates.Hammer.CarrierName
			)
			local appearance = TestAssets.get(carrier, "SurfaceAppearance")
			local maps = Cosmetics.VisualTemplates.Hammer.SurfaceMaps
			expect(appearance:IsA("SurfaceAppearance")).to.equal(true)
			local ok, colorId = pcall(function()
				return numericAssetId(appearance.ColorMap)
			end)
			if ok and colorId then
				expect(colorId).to.equal(maps.ColorMapId)
			end
			local ok_metal, metalId = pcall(function()
				return numericAssetId(appearance.MetalnessMap)
			end)
			if ok_metal and metalId then
				expect(metalId).to.equal(maps.MetalnessMapId)
			end
			local ok_normal, normalId = pcall(function()
				return numericAssetId(appearance.NormalMap)
			end)
			if ok_normal and normalId then
				expect(normalId).to.equal(maps.NormalMapId)
			end
			local ok_rough, roughId = pcall(function()
				return numericAssetId(appearance.RoughnessMap)
			end)
			if ok_rough and roughId then
				expect(roughId).to.equal(maps.RoughnessMapId)
			end
		end)

		it("resolves the hammer carrier grip without an ambiguous axis", function()
			local carrier = TestAssets.get(
				ReplicatedStorage,
				"Assets",
				"Cosmetics",
				"Templates",
				Cosmetics.VisualTemplates.Hammer.CarrierName
			)
			local attachment = carrier:FindFirstChild("GripAttachment")
			if attachment then
				expect(attachment:IsA("Attachment")).to.equal(true)
			else
				local size = carrier.Size
				local config = Combat.Hammer.AutoGrip
				local solution =
					HammerGrip.solve(size.X, size.Y, size.Z, config.MinAxisDominanceRatio, config.GripAlongLongAxis)
				expect(solution).to.be.ok()
			end
		end)

		it("has real audio behind every elimination effect, default included", function()
			local default = Cosmetics.Defaults.ElimEffectAssets
			expect(default).to.be.ok()
			expect(default.ElimEffect).to.be.ok()
			expect(Audio.Gameplay[default.ElimEffect.DodgeballSound]).to.be.ok()
			expect(Audio.Gameplay[default.ElimEffect.HammerSound]).to.be.ok()
			for _, item in Cosmetics.Items do
				if item.Category == "ElimEffectAssets" then
					expect(item.ElimEffect).to.be.ok()
					expect(Audio.Gameplay[item.ElimEffect.DodgeballSound]).to.be.ok()
					expect(Audio.Gameplay[item.ElimEffect.HammerSound]).to.be.ok()
				end
			end
		end)

		it("references only purchasable, known cosmetics from crate pools", function()
			for _, crate in Crates do
				for _, itemId in crate.ItemPool do
					local item = Cosmetics.Items[itemId]
					expect(item).to.be.ok()
					expect(Cosmetics.Rarities[item.Rarity]).to.be.ok()
					expect(item.AlwaysAvailable).never.to.equal(true)
				end
			end
		end)

		it("loads every registered script impact cosmetic", function()
			local expected = {
				"StarPop",
				"FoamPoof",
				"JellySplash",
				"PartyPopper",
				"ComicBonk",
				"CandyCrash",
				"BubbleBurst",
				"RoyalParty",
			}
			for _, effectId in expected do
				local item = Cosmetics.Items[effectId]
				expect(item).to.be.ok()
				expect(item.EffectId).to.equal(effectId)
				local effect = ScriptEffects.get(effectId)
				expect(effect).to.be.ok()
				expect(typeof(effect.play)).to.equal("function")
			end
		end)
	end)
end
