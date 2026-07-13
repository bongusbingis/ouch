--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Maps = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Maps"))

-- Owns the lifecycle of the active map: pick, clone into Workspace, expose
-- spawn points, teleport characters, despawn. Maps are authored at their
-- final world position, so spawning is a plain clone.

local MapService = {}

export type ActiveMap = {
	id: string,
	instance: Instance,
	ballSpawns: { BasePart },
	playerSpawns: { BasePart },
}

local active: ActiveMap? = nil
local lastMapId: string? = nil

local function partsOf(folder: Instance): { BasePart }
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

local function pickEntry(): Maps.MapEntry
	local pool = Maps.Pool
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

-- TODO(voting): replace pickEntry with the winning vote when map voting lands.
function MapService.spawnRandom(): ActiveMap
	MapService.despawn()
	local entry = pickEntry()
	lastMapId = entry.Id

	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Maps"):WaitForChild(entry.AssetName)
	local clone = template:Clone()
	clone.Parent = Workspace

	local scriptables = clone:WaitForChild("Scriptables")
	local map: ActiveMap = {
		id = entry.Id,
		instance = clone,
		ballSpawns = partsOf(scriptables:WaitForChild("BallSpawns")),
		playerSpawns = partsOf(scriptables:WaitForChild("PlayerSpawns")),
	}
	assert(#map.playerSpawns > 0, `[MapService] map "{entry.Id}" has no PlayerSpawns parts`)
	active = map
	return map
end

function MapService.active(): ActiveMap?
	return active
end

function MapService.despawn()
	if active then
		active.instance:Destroy()
		active = nil
	end
end

function MapService.teleport(character: Model)
	local map = assert(active, "[MapService] teleport with no active map")
	local spawnPart = map.playerSpawns[math.random(#map.playerSpawns)]
	character:WaitForChild("HumanoidRootPart")
	character:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3.5, 0)) * spawnPart.CFrame.Rotation)
end

return MapService
