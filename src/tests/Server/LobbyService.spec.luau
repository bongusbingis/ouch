--!nonstrict
-- LobbyService against the permanent Studio-authored Workspace.Lobby: spawn
-- validation, teleport targets, and the never-clone/never-destroy invariant.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LobbyService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("LobbyService"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))
local TestAssets = require(Helpers:WaitForChild("TestAssets"))

return function()
	describe("LobbyService", function()
		it("validates the authored lobby without touching it", function()
			local lobby = TestAssets.get(Workspace, "Lobby")
			local childCountBefore = #lobby:GetChildren()

			LobbyService.start()

			expect(lobby.Parent).to.equal(Workspace)
			expect(#lobby:GetChildren()).to.equal(childCountBefore)
		end)

		it("teleports characters above one of the lobby's player spawns", function()
			local spawnsFolder = TestAssets.get(Workspace, "Lobby", "PlayerSpawns")
			local rig = CharacterFixture.create()

			LobbyService.teleport(rig)

			local pivot = rig:GetPivot().Position
			local nearestDistance = math.huge
			for _, part in spawnsFolder:GetChildren() do
				if part:IsA("BasePart") then
					local distance = (pivot - (part.Position + Vector3.new(0, 3.5, 0))).Magnitude
					nearestDistance = math.min(nearestDistance, distance)
				end
			end
			expect(nearestDistance).to.be.near(0, 0.05)

			CharacterFixture.destroy(rig)
		end)
	end)
end
