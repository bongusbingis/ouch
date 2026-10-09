--!strict

local Workspace = game:GetService("Workspace")

return function()
	describe("Lobby scene readiness", function()
		it("keeps the required backdrop and page cameras available before loading completes", function()
			local party = Workspace:WaitForChild("Views"):WaitForChild("Party")
			expect(party:IsA("Model")).to.equal(true)
			expect((party :: Model).ModelStreamingMode).to.equal(Enum.ModelStreamingMode.Persistent)
			for _, name in { "Background", "SplashScreenCamera", "InventoryCamera", "ShopCamera" } do
				expect(party:WaitForChild(name):IsA("BasePart")).to.equal(true)
			end
		end)
	end)
end
