-- Description: Validates the permanent Studio-authored arena and its spawn folders at startup, teleports players onto general or per-team spawn parts without cloning or modifying arena content, and resolves the points loose dodgeballs replenish at and return to.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Workspace = game:GetService("Workspace")
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)
local Volume = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures"):WaitForChild("Volume")
)

local ArenaService = {}

export type Arena = {
	root: Folder,
	map: Folder,
	scriptables: Folder,
	origin: BasePart,
	playerSpawns: { BasePart },
	teamSpawns: { [string]: { BasePart } },
	ballSpawns: { BasePart },
}

local arena: Arena? = nil
local warnedMissingTeamSpawns: { [string]: boolean } = {}

local function spawnParts(folder: Folder, path: string, origin: Vector3): { BasePart }
	local parts = {}
	for _, child in folder:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		local distance = (child.Position - origin).Magnitude
		if distance > MapFeatures.Spawns.MaxOriginDistanceStuds then
			warn(`[ArenaService] {path}.{child.Name} is {distance} studs from MapOrigin -- excluding corrupted spawn`)
			continue
		end
		table.insert(parts, child)
	end
	assert(#parts > 0, `[ArenaService] {path} must contain at least one usable BasePart`)
	return parts
end

local function requireFolder(parent: Instance, name: string, path: string): Folder
	local folder = parent:WaitForChild(name)
	assert(folder:IsA("Folder"), `[ArenaService] {path} must be a Folder`)
	return folder
end

-- Where loose dodgeballs replenish, and where one that fell out of the world is
-- returned to. Authored Scriptables.BallSpawns wins when it exists; otherwise the
-- spawn markers stand in, because they are already grounded, hazard-checked and
-- spread across the three regions play actually happens in. Deriving rather than
-- requiring a folder means the arena keeps a working ball supply without a
-- Studio authoring pass, and gains a tuned one the moment it gets one.
local function ballSpawnParts(
	scriptables: Folder,
	playerSpawns: { BasePart },
	teamSpawns: { [string]: { BasePart } }
): { BasePart }
	local authored = scriptables:FindFirstChild("BallSpawns")
	if authored and authored:IsA("Folder") then
		local parts = {}
		for _, child in authored:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		if #parts > 0 then
			return parts
		end
	end

	local derived = table.clone(playerSpawns)
	for _, teamId in { "Red", "Blue" } do
		for _, part in teamSpawns[teamId] or {} do
			table.insert(derived, part)
		end
	end
	return derived
end

function ArenaService.start(): Arena
	if arena then
		return arena
	end

	local assets = requireFolder(Workspace, "Assets", "Workspace.Assets")
	local root = requireFolder(assets, "Arena", "Workspace.Assets.Arena")
	local origin = root:WaitForChild("MapOrigin")
	assert(origin:IsA("BasePart"), "[ArenaService] Workspace.Assets.Arena.MapOrigin must be a BasePart")
	local function projectOrigin()
		root:SetAttribute("MapOriginPosition", origin.Position)
	end
	projectOrigin()
	origin:GetPropertyChangedSignal("Position"):Connect(projectOrigin)
	local playerSpawnsFolder = requireFolder(root, "PlayerSpawns", "Workspace.Assets.Arena.PlayerSpawns")
	local teamSpawnsFolder = requireFolder(root, "TeamSpawns", "Workspace.Assets.Arena.TeamSpawns")
	local redSpawns = requireFolder(teamSpawnsFolder, "Red", "Workspace.Assets.Arena.TeamSpawns.Red")
	local blueSpawns = requireFolder(teamSpawnsFolder, "Blue", "Workspace.Assets.Arena.TeamSpawns.Blue")

	local scriptables = requireFolder(root, "Scriptables", "Workspace.Assets.Arena.Scriptables")
	local playerSpawns = spawnParts(playerSpawnsFolder, "Workspace.Assets.Arena.PlayerSpawns", origin.Position)
	local teamSpawns = {
		Red = spawnParts(redSpawns, "Workspace.Assets.Arena.TeamSpawns.Red", origin.Position),
		Blue = spawnParts(blueSpawns, "Workspace.Assets.Arena.TeamSpawns.Blue", origin.Position),
	}

	arena = {
		root = root,
		map = requireFolder(root, "Map", "Workspace.Assets.Arena.Map"),
		scriptables = scriptables,
		origin = origin,
		playerSpawns = playerSpawns,
		teamSpawns = teamSpawns,
		ballSpawns = ballSpawnParts(scriptables, playerSpawns, teamSpawns),
	}
	assert(#arena.playerSpawns >= GameModes.MatchCapacity, "[ArenaService] PlayerSpawns must cover MatchCapacity")
	for teamId, spawns in arena.teamSpawns do
		assert(
			#spawns >= math.ceil(GameModes.MatchCapacity / 2),
			`[ArenaService] {teamId} requires half MatchCapacity spawns`
		)
	end
	return arena
end

function ArenaService.get(): Arena
	return ArenaService.start()
end

-- Live hazard geometry, read fresh each teleport rather than cached on Arena,
-- since ElimZones can be authored/moved while the round is running.
local function hazardParts(current: Arena): { BasePart }
	local folder = current.scriptables:FindFirstChild("ElimZones")
	if folder == nil or not folder:IsA("Folder") then
		return {}
	end
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

local function isSpawnSafe(spawnPart: BasePart, hazards: { BasePart }): boolean
	local position = spawnPart.Position + Vector3.new(0, MapFeatures.Spawns.RootOffsetStuds, 0)
	for _, hazard in hazards do
		if Volume.contains(hazard.CFrame, hazard.Size, position, MapFeatures.ElimZone.VerticalPadding) then
			return false
		end
	end
	return true
end

function ArenaService.teleport(character: Model, teamId: string?)
	local current = ArenaService.start()
	local authored: { BasePart }? = if teamId == nil then current.playerSpawns else current.teamSpawns[teamId]
	-- A mode may name teams the map has no authored spawn set for. Falling back to
	-- the general spawns costs that mode its spawn separation; asserting instead
	-- failed the whole match start, which is how Infection came to be unstartable
	-- rather than merely unseparated.
	if (authored == nil or #authored == 0) and teamId ~= nil and not warnedMissingTeamSpawns[teamId] then
		warnedMissingTeamSpawns[teamId] = true
		warn(`[ArenaService] no authored spawns for team "{teamId}" -- using PlayerSpawns`)
	end
	local spawns: { BasePart } = if authored ~= nil and #authored > 0 then authored else current.playerSpawns
	assert(#spawns > 0, "[ArenaService] PlayerSpawns must contain at least one usable BasePart")
	local root = character:WaitForChild("HumanoidRootPart")
	assert(root:IsA("BasePart"), "[ArenaService] HumanoidRootPart must be a BasePart")

	local hazards = hazardParts(current)
	local safeSpawns = spawns
	if #hazards > 0 then
		local filtered = {}
		for _, candidate in spawns do
			if isSpawnSafe(candidate, hazards) then
				table.insert(filtered, candidate)
			end
		end
		if #filtered > 0 then
			safeSpawns = filtered
		else
			warn(`[ArenaService] every spawn point for team "{teamId or "none"}" overlaps a hazard; spawning anyway`)
		end
	end

	local spawnPart = safeSpawns[math.random(#safeSpawns)]
	local bestClearance = -1
	for _, candidate in safeSpawns do
		local clearance = math.huge
		for _, player in Players:GetPlayers() do
			local other = player.Character
			local otherRoot = if other then other:FindFirstChild("HumanoidRootPart") else nil
			if
				other
				and other ~= character
				and other:GetAttribute("CombatAlive") ~= false
				and otherRoot
				and otherRoot:IsA("BasePart")
			then
				clearance = math.min(clearance, (otherRoot.Position - candidate.Position).Magnitude)
			end
		end
		if clearance < math.huge and clearance > bestClearance then
			bestClearance = clearance
			spawnPart = candidate
		end
	end
	local target = CFrame.new(spawnPart.Position + Vector3.new(0, MapFeatures.Spawns.RootOffsetStuds, 0))
		* spawnPart.CFrame.Rotation
	character:PivotTo(target * root.CFrame:Inverse() * character:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	MovementGuard.reset(root)
end

return ArenaService
