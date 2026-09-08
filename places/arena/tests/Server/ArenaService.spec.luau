-- Description: In-place spec that the arena service resolves the authored arena without modifying it and teleports players onto the right spawn pool for team and non-team modes.

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ArenaService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("ArenaService"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))

local function landedAt(rig: Model, spawns: { BasePart }): boolean
	local pivot = rig:GetPivot().Position
	for _, spawnPart in spawns do
		if (pivot - (spawnPart.Position + Vector3.new(0, 3.5, 0))).Magnitude < 0.05 then
			return true
		end
	end
	return false
end

return function()
	describe("ArenaService", function()
		it("resolves the authored arena without cloning or reparenting it", function()
			local childCount = #Workspace.Assets.Arena:GetChildren()
			local arena = ArenaService.start()

			expect(arena.root).to.equal(Workspace.Assets.Arena)
			expect(arena.root.Parent).to.equal(Workspace.Assets)
			expect(#arena.root:GetChildren()).to.equal(childCount)
		end)

		it("uses general spawns for non-team modes", function()
			local arena = ArenaService.get()
			local rig = CharacterFixture.create()

			ArenaService.teleport(rig, nil)
			expect(landedAt(rig, arena.playerSpawns)).to.equal(true)
			CharacterFixture.destroy(rig)
		end)

		it("uses the authored spawn pool for each TDM team", function()
			local arena = ArenaService.get()
			for _, teamId in { "Red", "Blue" } do
				local rig = CharacterFixture.create()
				ArenaService.teleport(rig, teamId)
				expect(landedAt(rig, arena.teamSpawns[teamId])).to.equal(true)
				CharacterFixture.destroy(rig)
			end
		end)
	end)
end
