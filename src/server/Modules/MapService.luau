--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Maps = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Maps"))

-- Owns the lifecycle of the active map: pick, clone into Workspace, expose
-- spawn points, teleport characters, despawn. Maps are authored at their
-- final world position, so spawning is a plain clone.
--
-- Spawn pools are flat: every BasePart under BallSpawns/PlayerSpawns counts,
-- regardless of subfolder structure. Team ownership is not authored — it is
-- assigned per match by MatchService (TeamSpawns split) via assignTeamSpawns.

local MapService = {}

export type ActiveMap = {
	id: string,
	instance: Instance,
	ballSpawns: { BasePart },
	playerSpawns: { BasePart },
	bouncePads: { BasePart },
	foamPits: { BasePart },
	recoveryY: number,
}

local active: ActiveMap? = nil
local lastMapId: string? = nil
local teamAssignments: { [string]: { BasePart } } = {}

local function partsOf(folder: Instance): { BasePart }
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

local function allPartsOf(folder: Instance): { BasePart }
	local parts = {}
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function anchorStaticParts(mapRoot: Instance)
	local static = mapRoot:WaitForChild("Static")
	for _, part in allPartsOf(static) do
		part.Anchored = true
	end
end

-- BouncePads/FoamPits folders are optional per map (e.g. The Pit has none).
local function optionalPartsOf(parent: Instance, folderName: string): { BasePart }
	local folder = parent:FindFirstChild(folderName)
	return if folder then partsOf(folder) else {}
end

local function pickEntry(): Maps.MapEntry
	local pool = {}
	for _, entry in Maps.Pool do
		if entry.Enabled then
			table.insert(pool, entry)
		end
	end
	assert(#pool > 0, "[MapService] Maps.Pool is empty")
	local candidates = {}
	for _, entry in pool do
		if entry.Id ~= lastMapId then
			table.insert(candidates, entry)
		end
	end
	if #candidates == 0 then
		candidates = pool
	end
	return candidates[math.random(#candidates)]
end

local function entryById(mapId: string): Maps.MapEntry?
	for _, entry in Maps.Pool do
		if entry.Id == mapId then
			return entry
		end
	end
	return nil
end

local function spawnEntry(entry: Maps.MapEntry): ActiveMap
	MapService.despawn()
	lastMapId = entry.Id

	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Maps"):WaitForChild(entry.AssetName)
	local clone = template:Clone()
	anchorStaticParts(clone)
	clone.Parent = Workspace

	local scriptables = clone:WaitForChild("Scriptables")
	local map: ActiveMap = {
		id = entry.Id,
		instance = clone,
		ballSpawns = allPartsOf(scriptables:WaitForChild("BallSpawns")),
		playerSpawns = allPartsOf(scriptables:WaitForChild("PlayerSpawns")),
		bouncePads = optionalPartsOf(scriptables, "BouncePads"),
		foamPits = optionalPartsOf(scriptables, "FoamPits"),
		recoveryY = entry.RecoveryY,
	}
	assert(#map.ballSpawns > 0, `[MapService] map "{entry.Id}" has no BallSpawns parts`)
	assert(#map.playerSpawns > 0, `[MapService] map "{entry.Id}" has no PlayerSpawns parts`)
	active = map
	return map
end

function MapService.spawnRandom(): ActiveMap
	return spawnEntry(pickEntry())
end

function MapService.spawnById(mapId: string): ActiveMap?
	local entry = entryById(mapId)
	return if entry and entry.Enabled then spawnEntry(entry) else nil
end

function MapService.hasMap(mapId: string): boolean
	local entry = entryById(mapId)
	return entry ~= nil and entry.Enabled
end

function MapService.isCompatible(mapId: string, modeId: string): boolean
	local entry = entryById(mapId)
	return entry ~= nil and entry.Enabled and table.find(entry.ModeIds, modeId) ~= nil
end

function MapService.entriesForMode(modeId: string): { Maps.MapEntry }
	local entries = {}
	for _, entry in Maps.Pool do
		if entry.Enabled and table.find(entry.ModeIds, modeId) then
			table.insert(entries, entry)
		end
	end
	return entries
end

function MapService.active(): ActiveMap?
	return active
end

function MapService.assignTeamSpawns(byTeam: { [string]: { BasePart } })
	teamAssignments = byTeam
end

function MapService.despawn()
	teamAssignments = {}
	if active then
		active.instance:Destroy()
		active = nil
	end
end

function MapService.teleport(character: Model, teamId: string?)
	local map = assert(active, "[MapService] teleport with no active map")
	local teamSpawns = if teamId then teamAssignments[teamId] else nil
	local spawns = if teamSpawns and #teamSpawns > 0 then teamSpawns else map.playerSpawns
	assert(#spawns > 0, `[MapService] no spawn points available for team "{teamId or "none"}"`)
	local spawnPart = spawns[math.random(#spawns)]
	character:WaitForChild("HumanoidRootPart")
	character:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3.5, 0)) * spawnPart.CFrame.Rotation)
end

return MapService
