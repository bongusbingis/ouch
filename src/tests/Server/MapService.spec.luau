--!nonstrict
-- MapService against the real Studio-authored maps: clone lifecycle, flat
-- spawn pools, team spawn assignment, and character teleports onto real spawn
-- parts. Previously untestable headlessly (needs the real DataModel + assets).

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MapService"))
local Maps = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Maps"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))

local function poolIds(): { [string]: boolean }
	local ids = {}
	for _, entry in Maps.Pool do
		ids[entry.Id] = true
	end
	return ids
end

return function()
	describe("MapService", function()
		afterEach(function()
			MapService.despawn()
		end)

		it("spawns a configured map into Workspace with flat spawn pools", function()
			local map = MapService.spawnRandom()

			expect(poolIds()[map.id]).to.equal(true)
			expect(map.instance.Parent).to.equal(Workspace)
			expect(#map.playerSpawns > 0).to.equal(true)
			expect(#map.ballSpawns > 0).to.equal(true)
			for _, part in map.playerSpawns do
				expect(part:IsA("BasePart")).to.equal(true)
				expect(part:IsDescendantOf(map.instance)).to.equal(true)
			end
			expect(MapService.active()).to.equal(map)
		end)

		it("despawn destroys the active map and clears active()", function()
			local map = MapService.spawnRandom()
			local instance = map.instance

			MapService.despawn()

			expect(instance.Parent).never.to.be.ok()
			expect(MapService.active()).never.to.be.ok()
		end)

		it("does not repeat the previous map when the pool allows it", function()
			if #Maps.Pool < 2 then
				return
			end
			local firstId = MapService.spawnRandom().id
			for _ = 1, 8 do
				local nextId = MapService.spawnRandom().id
				expect(nextId == firstId).to.equal(false)
				firstId = nextId
			end
		end)

		it("teleports characters above one of the map's player spawns", function()
			local map = MapService.spawnRandom()
			local rig = CharacterFixture.create()

			MapService.teleport(rig, nil)

			local pivot = rig:GetPivot().Position
			local landed = false
			for _, part in map.playerSpawns do
				if (pivot - (part.Position + Vector3.new(0, 3.5, 0))).Magnitude < 1e-3 then
					landed = true
					break
				end
			end
			expect(landed).to.equal(true)

			CharacterFixture.destroy(rig)
		end)

		it("prefers assigned team spawns for team teleports", function()
			local map = MapService.spawnRandom()
			local rig = CharacterFixture.create()
			local teamSpawn = map.playerSpawns[1]
			MapService.assignTeamSpawns({ Red = { teamSpawn } })

			MapService.teleport(rig, "Red")

			local expected = teamSpawn.Position + Vector3.new(0, 3.5, 0)
			expect((rig:GetPivot().Position - expected).Magnitude).to.be.near(0, 1e-3)

			CharacterFixture.destroy(rig)
		end)

		it("falls back to the full pool for unassigned teams", function()
			local map = MapService.spawnRandom()
			local rig = CharacterFixture.create()
			MapService.assignTeamSpawns({})

			MapService.teleport(rig, "Blue")

			local pivot = rig:GetPivot().Position
			local landed = false
			for _, part in map.playerSpawns do
				if (pivot - (part.Position + Vector3.new(0, 3.5, 0))).Magnitude < 1e-3 then
					landed = true
					break
				end
			end
			expect(landed).to.equal(true)

			CharacterFixture.destroy(rig)
		end)

		it("rejects teleports with no active map", function()
			MapService.despawn()
			local rig = CharacterFixture.create()

			expect(function()
				MapService.teleport(rig, nil)
			end).to.throw()

			CharacterFixture.destroy(rig)
		end)
	end)
end
