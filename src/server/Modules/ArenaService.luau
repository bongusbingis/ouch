--!strict

local Workspace = game:GetService("Workspace")

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
	return arena
end

function ArenaService.get(): Arena
	return ArenaService.start()
end

function ArenaService.teleport(character: Model, teamId: string?)
	local current = ArenaService.start()
	local spawns = if teamId == nil then current.playerSpawns else current.teamSpawns[teamId]
	assert(spawns ~= nil and #spawns > 0, `[ArenaService] no spawn points configured for team "{teamId or "none"}"`)
	local spawnPart = spawns[math.random(#spawns)]
	character:WaitForChild("HumanoidRootPart")
	character:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3.5, 0)) * spawnPart.CFrame.Rotation)
end

return ArenaService
