--!nonstrict
-- Validates authored cosmetic templates, procedural effects, and crate pools
-- against their config sources of truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerStorage = game:GetService("ServerStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates"))
local TrailCosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("TrailCosmetics"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))
local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local HammerGrip = require(Client:WaitForChild("Modules"):WaitForChild("Presentation"):WaitForChild("HammerGrip"))

return function()
	describe("Cosmetics assets", function()
		it("has a folder for every Studio-authored category", function()
			local authoredCategories = {}
			for category in Cosmetics.Defaults do
				authoredCategories[category] = true
			end
			for _, item in Cosmetics.Items do
				if item.AssetName ~= nil then
					authoredCategories[item.Category] = true
				end
			end

			for category in authoredCategories do
				local folderName = Cosmetics.CategoryFolders[category]
				expect(folderName).to.be.ok()
				TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", folderName)
			end
		end)

		it("has every configured default template", function()
			for category, default in Cosmetics.Defaults do
				local folderName = Cosmetics.CategoryFolders[category]
				expect(folderName).to.be.ok()
				local asset = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", folderName, default.AssetName)
				if category == "BallAssets" then
					expect(asset:IsA("BasePart")).to.equal(true)
				end
			end
		end)

		it("has a template for every catalog item", function()
			for _, item in Cosmetics.Items do
				if item.AssetName ~= nil then
					local folderName = Cosmetics.CategoryFolders[item.Category]
					expect(folderName).to.be.ok()
					local asset = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", folderName, item.AssetName)
					if item.Category == "BallAssets" then
						expect(asset:IsA("BasePart")).to.equal(true)
					end
				end
			end
		end)

		it("resolves every hammer grip without guessing an ambiguous axis", function()
			local assetNames = { Cosmetics.Defaults.HammerAssets.AssetName }
			for _, item in Cosmetics.Items do
				if item.Category == "HammerAssets" and item.AssetName ~= nil then
					table.insert(assetNames, item.AssetName)
				end
			end
			for _, assetName in assetNames do
				local asset = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "HammerAssets", assetName)
				expect(asset:IsA("BasePart")).to.equal(true)
				local attachment = asset:FindFirstChild("GripAttachment")
				if attachment then
					expect(attachment:IsA("Attachment")).to.equal(true)
				else
					local size = asset.Size
					local config = Combat.Hammer.AutoGrip
					local solution =
						HammerGrip.solve(size.X, size.Y, size.Z, config.MinAxisDominanceRatio, config.GripAlongLongAxis)
					expect(solution).to.be.ok()
				end
			end
		end)

		it("has a procedural definition for every effect-backed item", function()
			for _, item in Cosmetics.Items do
				if item.EffectId ~= nil then
					expect(TrailCosmetics[item.EffectId]).to.be.ok()
				end
			end
		end)

		it("references only known items and rarities from crate pools", function()
			for _, crate in Crates do
				for _, itemId in crate.ItemPool do
					local item = Cosmetics.Items[itemId]
					expect(item).to.be.ok()
					expect(Cosmetics.Rarities[item.Rarity]).to.be.ok()
				end
			end
		end)
	end)
end
