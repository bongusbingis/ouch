-- Both places mount shared inventory previews and must carry the same required rig contract.
--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))
local CharacterFixture = require(ServerStorage.Tests.Helpers.CharacterFixture)
local CostumeVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CostumeVisualFactory")
)

return function()
	describe("Shared preview assets", function()
		local fixture
		afterEach(function()
			CharacterFixture.destroy(fixture)
			fixture = nil
		end)

		it("authors the character-color preview rig", function()
			local rig = TestAssets.get(ReplicatedStorage, "Assets", "Rigs", "CharacterRig")
			expect(rig:IsA("Model")).to.equal(true)
			expect(TestAssets.get(rig, "HumanoidRootPart"):IsA("BasePart")).to.equal(true)
			expect(TestAssets.get(rig, "Head"):IsA("BasePart")).to.equal(true)
			expect(TestAssets.get(rig, "Humanoid"):IsA("Humanoid")).to.equal(true)
		end)

		it("uses the published player blob meshes and proportions for party and preview rigs", function()
			local rig = TestAssets.get(ReplicatedStorage, "Assets", "Rigs", "CharacterRig")
			fixture = CharacterFixture.createBlob()
			local previewScale = TestAssets.get(rig, "HumanoidRootPart").Size.Y
			local liveScale = TestAssets.get(fixture, "HumanoidRootPart").Size.Y
			for name in CostumeVisualFactory.BodyParts do
				local preview = TestAssets.get(rig, name)
				local loaded = TestAssets.get(fixture, name)
				expect(preview:IsA("MeshPart") and loaded:IsA("MeshPart")).to.equal(true)
				expect(preview.MeshId).to.equal(loaded.MeshId)
				expect((preview.Size / previewScale - loaded.Size / liveScale).Magnitude < 0.00001).to.equal(true)
				for _, attachment in preview:GetChildren() do
					if attachment:IsA("Attachment") and attachment.Name:match("RigAttachment$") then
						expect(TestAssets.get(loaded, attachment.Name):IsA("Attachment")).to.equal(true)
					end
				end
			end
		end)
	end)
end
