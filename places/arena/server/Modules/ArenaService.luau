-- Description: Validates the permanent Studio-authored arena and its spawn folders at startup and teleports players onto general or per-team spawn parts without cloning or modifying arena content.

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

local ArenaService = {}

export type Arena = {
	root: Folder,
	map: Folder,
	scriptables: Folder,
	playerSpawns: { BasePart },
	teamSpawns: { [string]: { BasePart } },
}

local arena: Arena? = nil

local function spawnParts(folder: Folder, path: string): { BasePart }
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	assert(#parts > 0, `[ArenaService] {path} must contain at least one BasePart`)
	return parts
end

local function requireFolder(parent: Instance, name: string, path: string): Folder
	local folder = parent:WaitForChild(name)
	assert(folder:IsA("Folder"), `[ArenaService] {path} must be a Folder`)
	return folder
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

	arena = {
		root = root,
		map = requireFolder(root, "Map", "Workspace.Assets.Arena.Map"),
		scriptables = requireFolder(root, "Scriptables", "Workspace.Assets.Arena.Scriptables"),
		playerSpawns = spawnParts(playerSpawnsFolder, "Workspace.Assets.Arena.PlayerSpawns"),
		teamSpawns = {
			Red = spawnParts(redSpawns, "Workspace.Assets.Arena.TeamSpawns.Red"),
			Blue = spawnParts(blueSpawns, "Workspace.Assets.Arena.TeamSpawns.Blue"),
		},
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

function ArenaService.teleport(character: Model, teamId: string?)
	local current = ArenaService.start()
	local spawns = if teamId == nil then current.playerSpawns else current.teamSpawns[teamId]
	assert(spawns ~= nil and #spawns > 0, `[ArenaService] no spawn points configured for team "{teamId or "none"}"`)
	local root = character:WaitForChild("HumanoidRootPart")
	assert(root:IsA("BasePart"), "[ArenaService] HumanoidRootPart must be a BasePart")
	local spawnPart = spawns[math.random(#spawns)]
	local bestClearance = -1
	for _, candidate in spawns do
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
