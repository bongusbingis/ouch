--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

return function()
	describe("Effect preview stage", function()
		it("provides a noninteractive stage and correctly aimed framing in both places", function()
			local scene = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "PreviewScene")
			expect(scene:IsA("Model")).to.equal(true)
			local impact = TestAssets.get(scene, "ImpactMarker")
			local camera = TestAssets.get(scene, "CameraMarker")
			for _, name in { "Origin", "ImpactMarker", "CameraMarker" } do
				local marker = TestAssets.get(scene, name)
				expect(marker:IsA("BasePart")).to.equal(true)
				expect(marker.Anchored).to.equal(true)
				expect(marker.Transparency).to.equal(1)
			end
			TestAssets.get(scene, "Ground")
			TestAssets.get(scene, "Backdrop")
			local direction = impact.Position - camera.Position
			expect(direction.Magnitude > 1).to.equal(true)
			expect(camera.CFrame.LookVector:Dot(direction.Unit) > 0.98).to.equal(true)
		end)
	end)
end
