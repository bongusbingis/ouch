--!nonstrict
-- Validates the permanent Studio-authored intermission lobby that
-- LobbyService depends on: Workspace.Lobby with a populated PlayerSpawns.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

return function()
	describe("Lobby assets", function()
		it("authors Workspace.Lobby with populated player spawns", function()
			local spawnsFolder = TestAssets.get(Workspace, "Lobby", "PlayerSpawns")

			local parts = 0
			for _, child in spawnsFolder:GetChildren() do
				if child:IsA("BasePart") then
					parts += 1
				end
			end
			expect(parts > 0).to.equal(true)
		end)
	end)
end
