-- Name: Cosmetics.spec.luau
-- Author: Jack C.
-- Description: In-place spec validating the authored cosmetic carriers, their meshes and textures, the hammer grip axis, elimination effect audio, and that crate pools only reference real purchasable items.
-- Created: 2026-07-16

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerStorage = game:GetService("ServerStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Crates"))
local Audio = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Audio"))
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

return function()
	describe("Cosmetics assets", function()
		it("has the effects carrier for templates that declare one", function()
			for _, definition in Cosmetics.VisualTemplates do
				if definition.EffectsCarrier then
					local carrier =
						TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "Templates", definition.EffectsCarrier)
					expect(carrier:IsA("MeshPart")).to.equal(true)
				end
			end
		end)

		it("resolves the hammer grip from config Size without an ambiguous axis", function()
			local templateDef = Cosmetics.VisualTemplates.Hammer
			local size = templateDef.Size
			local config = Combat.Hammer.AutoGrip
			local solution =
				HammerGrip.solve(size.X, size.Y, size.Z, config.MinAxisDominanceRatio, config.GripAlongLongAxis)
			expect(solution).to.be.ok()
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
