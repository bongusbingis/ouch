-- Description: In-place spec that the arena map service swaps a staged map into the permanent arena root by parking the live interior, refuses invalid or missing maps without disturbing the live one, and offers a ballot only when two valid maps exist.

--!nonstrict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local ArenaMaps = require(ReplicatedStorage.Config.Gameplay.ArenaMaps)
local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local ArenaService = require(Modules:WaitForChild("ArenaService"))
local ArenaMapService = require(Modules:WaitForChild("ArenaMapService"))
local LiveSession = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("LiveSession"))

-- Deliberately not a configured map, so a staged real map is never swapped by tests.
local FIXTURE_ID = "SpecFixtureMap"
local CONFIGURED_ID = "SecondMap"

local function part(name, position, parent)
	local created = Instance.new("Part")
	created.Name = name
	created.Anchored = true
	created.Position = position
	created.Parent = parent
	return created
end

local function folder(name, parent)
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local function buildTemplate(name, center, includeBlue)
	local container = Instance.new("Folder")
	container.Name = name
	folder("Map", container)
	local scriptables = folder("Scriptables", container)
	folder("ElimZones", scriptables)
	part("MapOrigin", center, container)
	local players = folder("PlayerSpawns", container)
	for index = 1, 20 do
		part(`P{index}`, center + Vector3.new(index, 1, 0), players)
	end
	local teams = folder("TeamSpawns", container)
	for _, teamId in { "Red", "Blue" } do
		if teamId == "Blue" and not includeBlue then
			continue
		end
		local team = folder(teamId, teams)
		for index = 1, 10 do
			part(`{teamId}{index}`, center + Vector3.new(index, 1, 5), team)
		end
	end
	return container
end

local function childSet(container)
	local set = {}
	for _, child in container:GetChildren() do
		set[child] = true
	end
	return set
end

local function tagged(instance)
	return CollectionService:HasTag(instance, MapFeatures.Attributes.ScriptableRoot)
end

return function()
	describe("ArenaMapService", function()
		local maps, template, root, defaultTemplate, stashed

		beforeEach(function()
			root = ArenaService.get().root
			maps = ServerStorage:FindFirstChild("ArenaMaps")
			if maps == nil then
				maps = folder("ArenaMaps", ServerStorage)
				maps:SetAttribute("SpecOwned", true)
			end
			stashed = maps:FindFirstChild(ArenaMaps.Maps[CONFIGURED_ID].Template)
			if stashed then
				stashed.Parent = nil
			end
			template = buildTemplate(FIXTURE_ID, Vector3.new(5000, 0, 0), true)
			template.Parent = maps
			defaultTemplate = ArenaMaps.Maps[ArenaMaps.DefaultMapId].Template
		end)

		afterEach(function()
			-- Put the authored map back if a failed expectation left a swap in place.
			if ArenaMapService.currentMapId() ~= ArenaMaps.DefaultMapId then
				local park = maps:FindFirstChild(defaultTemplate)
				if park then
					ArenaMapService.swapTo(ArenaMaps.DefaultMapId, park)
				end
			end
			template:Destroy()
			if stashed then
				stashed.Parent = maps
			end
			local park = maps:FindFirstChild(defaultTemplate)
			if park and #park:GetChildren() == 0 then
				park:Destroy()
			end
			if maps:GetAttribute("SpecOwned") and #maps:GetChildren() == 0 then
				maps:Destroy()
			end
		end)

		-- Swaps the singleton Workspace.Assets.Arena interior, which a live match is using in Play.
		local ownsArenaIt = LiveSession.guardedIt(it, itSKIP)
		ownsArenaIt("swaps a staged map in, parks the live interior and swaps back without residue", function()
			local original = childSet(root)
			local originalCount = #root:GetChildren()
			local originalScriptables = ArenaService.get().scriptables
			local fixtureScriptables = template.Scriptables
			local fixtureOrigin = template.MapOrigin

			local ok = ArenaMapService.swapTo(FIXTURE_ID, template)
			expect(ok).to.equal(true)
			expect(ArenaService.get().origin).to.equal(fixtureOrigin)
			expect(root:GetAttribute("ArenaMapId")).to.equal(FIXTURE_ID)
			expect(ArenaMapService.currentMapId()).to.equal(FIXTURE_ID)
			expect(tagged(originalScriptables)).to.equal(false)
			expect(tagged(fixtureScriptables)).to.equal(true)
			expect(#template:GetChildren()).to.equal(0)
			local park = maps:FindFirstChild(defaultTemplate)
			expect(park).to.be.ok()
			expect(#park:GetChildren()).to.equal(originalCount)
			for child in original do
				expect(child.Parent).to.equal(park)
			end

			local back = ArenaMapService.swapTo(ArenaMaps.DefaultMapId, park)
			expect(back).to.equal(true)
			expect(#root:GetChildren()).to.equal(originalCount)
			for child in original do
				expect(child.Parent).to.equal(root)
			end
			expect(#park:GetChildren()).to.equal(0)
			expect(fixtureScriptables.Parent).to.equal(template)
			expect(root:GetAttribute("ArenaMapId")).to.equal(ArenaMaps.DefaultMapId)
			expect(tagged(originalScriptables)).to.equal(true)
			expect(tagged(fixtureScriptables)).to.equal(false)
		end)

		it("refuses an invalid staged map and leaves the live interior and tags untouched", function()
			local broken = buildTemplate("Broken", Vector3.new(5000, 0, 0), false)
			broken.Parent = maps
			local before = childSet(root)
			local liveScriptables = ArenaService.get().scriptables

			local ok, reason = ArenaMapService.swapTo(FIXTURE_ID, broken)
			expect(ok).to.equal(false)
			expect(type(reason)).to.equal("string")
			expect(ArenaService.get().scriptables).to.equal(liveScriptables)
			expect(tagged(liveScriptables)).to.equal(true)
			expect(tagged(broken.Scriptables)).to.equal(false)
			for child in before do
				expect(child.Parent).to.equal(root)
			end
			expect(ArenaMapService.currentMapId()).to.equal(ArenaMaps.DefaultMapId)
			broken:Destroy()
		end)

		it("returns false for a missing template without throwing", function()
			local ok, reason = ArenaMapService.activate(CONFIGURED_ID)
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("refuses a swap whose parking folder is not empty", function()
			local park = folder(defaultTemplate, maps)
			local residue = part("Residue", Vector3.zero, park)
			local ok, reason = ArenaMapService.swapTo(FIXTURE_ID, template)
			expect(ok).to.equal(false)
			expect(reason).to.equal("park_not_empty")
			expect(ArenaMapService.currentMapId()).to.equal(ArenaMaps.DefaultMapId)
			expect(tagged(template.Scriptables)).to.equal(false)
			residue:Destroy()
		end)

		it("treats activating the live map as a no-op", function()
			local ok = ArenaMapService.activate(ArenaMapService.currentMapId())
			expect(ok).to.equal(true)
			expect(root:GetAttribute("ArenaMapId")).never.to.equal(nil)
		end)

		it("offers a ballot only when two valid maps exist", function()
			template.Name = ArenaMaps.Maps[CONFIGURED_ID].Template
			expect(#ArenaMapService.availableMaps()).to.equal(2)
			template:Destroy()
			expect(#ArenaMapService.availableMaps()).to.equal(0)
		end)
	end)
end
