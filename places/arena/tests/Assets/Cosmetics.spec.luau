-- Description: In-place spec validating the authored cosmetic carriers, their meshes and textures, the hammer grip axis, elimination effect audio, and that crate pools only reference real purchasable items.

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
		it("has an authored template MeshPart carrying each visual template's mesh", function()
			for name, definition in Cosmetics.VisualTemplates do
				local template = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "Templates", name)
				expect(template:IsA("MeshPart")).to.equal(true)
				expect(template.MeshId).to.equal(`rbxassetid://{definition.MeshId}`)
			end
		end)

		-- A mesh and its PBR maps are authored, never written at runtime, so config
		-- and the authored asset are two records of one thing. These hold them in
		-- agreement: without this a mis-imported or misnamed part renders the wrong
		-- skin with nothing failing.
		it("has an authored MeshPart for every item in a category that has visuals", function()
			for itemId, item in Cosmetics.Items do
				local folder = Cosmetics.VisualFolders[item.Category]
				if folder == nil or item.Visual == nil then
					continue
				end
				local part = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", folder, itemId)
				expect(part:IsA("MeshPart")).to.equal(true)
				local templateDef = Cosmetics.VisualTemplates[item.Visual.Template]
				expect(part.MeshId).to.equal(`rbxassetid://{item.Visual.MeshId or templateDef.MeshId}`)
			end
		end)

		it("matches every authored SurfaceAppearance to the maps its item declares", function()
			for itemId, item in Cosmetics.Items do
				local folder = Cosmetics.VisualFolders[item.Category]
				if folder == nil or item.Visual == nil then
					continue
				end
				local templateDef = Cosmetics.VisualTemplates[item.Visual.Template]
				local maps = item.Visual.SurfaceMaps or templateDef.SurfaceMaps
				local part = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", folder, itemId)
				local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
				if maps == nil then
					expect(appearance).to.equal(nil)
					continue
				end
				expect(appearance).to.be.ok()
				for property, id in
					{
						ColorMap = maps.ColorMapId,
						MetalnessMap = maps.MetalnessMapId,
						NormalMap = maps.NormalMapId,
						RoughnessMap = maps.RoughnessMapId,
					}
				do
					expect((appearance :: any)[property]).to.equal(`rbxassetid://{id}`)
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
