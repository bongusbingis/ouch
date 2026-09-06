-- Both places mount shared inventory previews and must carry the same required rig contract.
--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

return function()
	describe("Shared preview assets", function()
		it("authors the character-color preview rig", function()
			local rig = TestAssets.get(ReplicatedStorage, "Assets", "Rigs", "CharacterRig")
			expect(rig:IsA("Model")).to.equal(true)
			expect(TestAssets.get(rig, "HumanoidRootPart"):IsA("BasePart")).to.equal(true)
			expect(TestAssets.get(rig, "Head"):IsA("BasePart")).to.equal(true)
			expect(TestAssets.get(rig, "Humanoid"):IsA("Humanoid")).to.equal(true)
		end)
	end)
end
