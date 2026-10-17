-- Description: In-place spec that the arena service resolves the authored arena without modifying it and teleports players onto the right spawn pool for team and non-team modes.

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)

local ArenaService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("ArenaService"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))
local LiveSession = require(Helpers:WaitForChild("LiveSession"))

local function landedAt(rig: Model, spawns: { BasePart }): boolean
	local pivot = rig:GetPivot().Position
	for _, spawnPart in spawns do
		if (pivot - (spawnPart.Position + Vector3.new(0, 3.5, 0))).Magnitude < 0.05 then
			return true
		end
	end
	return false
end

local function part(name: string, position: Vector3, parent: Instance): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Anchored = true
	created.Position = position
	created.Parent = parent
	return created
end

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- A contract-satisfying arena interior: 20 general and 10 + 10 team spawns.
local function buildFixture(center: Vector3): Folder
	local container = Instance.new("Folder")
	container.Name = "ArenaServiceFixture"
	folder("Map", container)
	folder("Scriptables", container)
	part("MapOrigin", center, container)
	local players = folder("PlayerSpawns", container)
	for index = 1, 20 do
		part(`P{index}`, center + Vector3.new(index, 1, 0), players)
	end
	local teams = folder("TeamSpawns", container)
	for _, teamId in { "Red", "Blue" } do
		local team = folder(teamId, teams)
		for index = 1, 10 do
			part(`{teamId}{index}`, center + Vector3.new(index, 1, 5), team)
		end
	end
	return container
end

return function()
	describe("ArenaService", function()
		it("resolves the authored arena without cloning or reparenting it", function()
			local childCount = #Workspace.Assets.Arena:GetChildren()
			local arena = ArenaService.start()

			expect(arena.root).to.equal(Workspace.Assets.Arena)
			expect(arena.root.Parent).to.equal(Workspace.Assets)
			expect(#arena.root:GetChildren()).to.equal(childCount)
			expect(CollectionService:HasTag(arena.scriptables, MapFeatures.Attributes.ScriptableRoot)).to.equal(true)
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
		describe("validate", function()
			it("passes a fixture with 20 general and 10 + 10 team spawns", function()
				local fixture = buildFixture(Vector3.new(5000, 0, 0))
				local ok, reason = ArenaService.validate(fixture)
				expect(ok).to.equal(true)
				expect(reason).to.equal(nil)
				fixture:Destroy()
			end)

			it("rejects broken fixtures with a reason", function()
				local center = Vector3.new(5000, 0, 0)
				local cases = {
					function(f)
						f.MapOrigin:Destroy()
					end,
					function(f)
						f.PlayerSpawns:GetChildren()[1]:Destroy()
					end,
					function(f)
						f.TeamSpawns.Red:GetChildren()[1]:Destroy()
					end,
					function(f)
						f.PlayerSpawns:GetChildren()[1].Position = center
							+ Vector3.new(MapFeatures.Spawns.MaxOriginDistanceStuds + 50, 0, 0)
					end,
					function(f)
						f.Map:Destroy()
						Instance.new("Model", f).Name = "Map"
					end,
				}
				for _, mutate in cases do
					local fixture = buildFixture(center)
					mutate(fixture)
					local ok, reason = ArenaService.validate(fixture)
					expect(ok).to.equal(false)
					expect(type(reason)).to.equal("string")
					expect(CollectionService:HasTag(fixture.Scriptables, MapFeatures.Attributes.ScriptableRoot)).to.equal(
						false
					)
					fixture:Destroy()
				end
			end)
		end)

		describe("refresh", function()
			-- Replaces the singleton arena interior and origin listener the live match is using in Play.
			local ownsArenaIt = LiveSession.guardedIt(it, itSKIP)
			ownsArenaIt("re-resolves a replaced interior and stops following the old origin", function()
				local original = ArenaService.get()
				local root = original.root
				local originalOrigin = original.origin
				local parked = {}
				for _, child in root:GetChildren() do
					table.insert(parked, child)
				end
				local fixture = buildFixture(Vector3.new(5000, 0, 0))
				for _, child in parked do
					child.Parent = nil
				end
				for _, child in fixture:GetChildren() do
					child.Parent = root
				end

				local ok = ArenaService.refresh()
				expect(ok).to.equal(true)
				local refreshed = ArenaService.get()
				expect(refreshed.origin).never.to.equal(originalOrigin)
				expect(root:GetAttribute("MapOriginPosition")).to.equal(Vector3.new(5000, 0, 0))

				originalOrigin.Position = Vector3.new(1, 2, 3)
				expect(root:GetAttribute("MapOriginPosition")).to.equal(Vector3.new(5000, 0, 0))

				-- restore the authored interior
				for _, child in root:GetChildren() do
					child:Destroy()
				end
				for _, child in parked do
					child.Parent = root
				end
				expect(ArenaService.refresh()).to.equal(true)
				expect(ArenaService.get().origin).to.equal(originalOrigin)
				fixture:Destroy()
			end)
		end)
	end)
end
