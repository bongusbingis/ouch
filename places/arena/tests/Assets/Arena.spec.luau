--!nonstrict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

local function directPartCount(folder: Instance): number
	local count = 0
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return function()
	describe("Arena assets", function()
		it("authors the permanent arena and its required folders", function()
			local arena = TestAssets.get(Workspace, "Assets", "Arena")
			TestAssets.get(arena, "Map")
			TestAssets.get(arena, "Scriptables")

			local playerSpawns = TestAssets.get(arena, "PlayerSpawns")
			expect(directPartCount(playerSpawns) > 0).to.equal(true)

			local teamSpawns = TestAssets.get(arena, "TeamSpawns")
			expect(directPartCount(TestAssets.get(teamSpawns, "Red")) > 0).to.equal(true)
			expect(directPartCount(TestAssets.get(teamSpawns, "Blue")) > 0).to.equal(true)
		end)
	end)
end
