--!nonstrict
-- Validates the Studio-authored cosmetics catalog against Config.Cosmetics and
-- Config.Crates (the single sources of truth): every referenced template must
-- exist under ReplicatedStorage.Assets.Cosmetics with the right type. This is
-- exactly the setup drift the runtime would only surface as infinite yields.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

return function()
	describe("Cosmetics assets", function()
		it("has a folder for every configured category", function()
			for _, folderName in Cosmetics.CategoryFolders do
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
			for itemId, item in Cosmetics.Items do
				local folderName = Cosmetics.CategoryFolders[item.Category]
				expect(folderName).to.be.ok()
				local asset = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", folderName, item.AssetName)
				if item.Category == "BallAssets" then
					expect(asset:IsA("BasePart")).to.equal(true)
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
