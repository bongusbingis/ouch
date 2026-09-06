-- Name: Arena.spec.luau
-- Author: Jack C.
-- Description: In-place spec asserting the permanent authored arena exists with its map, scriptables, and spawn folders populated.
-- Created: 2026-08-17

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
		it("authors one neutral native spawn on the permanent map", function()
			local spawn = TestAssets.get(Workspace, "Assets", "Arena", "Map", "ArenaSpawn")
			expect(spawn:IsA("SpawnLocation")).to.equal(true)
			expect(spawn.Enabled and spawn.Neutral and spawn.Anchored).to.equal(true)
			expect(spawn.CanCollide or spawn.CanQuery or spawn.AllowTeamChangeOnTouch).to.equal(false)
			expect(spawn.Duration).to.equal(0)
			local count = 0
			for _, descendant in Workspace:GetDescendants() do
				if descendant:IsA("SpawnLocation") then
					count += 1
				end
			end
			expect(count).to.equal(1)
		end)
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
