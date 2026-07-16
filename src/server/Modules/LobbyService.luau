--!strict

local Workspace = game:GetService("Workspace")

-- Teleports returning match participants to the permanent Studio-authored
-- intermission area at Workspace.Lobby. New arrivals are not routed here.
-- Spawn points are invisible parts inside Workspace.Lobby.PlayerSpawns.

local LobbyService = {}

local lobby: Instance? = nil
local spawnParts: { BasePart }? = nil

local function lobbyRoot(): Instance
	if lobby then
		assert(lobby.Parent == Workspace, "[LobbyService] Workspace.Lobby must remain parented to Workspace")
		return lobby
	end
	local root = Workspace:WaitForChild("Lobby")
	lobby = root
	return root
end

local function lobbySpawns(): { BasePart }
	local root = lobbyRoot()
	if spawnParts then
		return spawnParts
	end
	local folder = root:WaitForChild("PlayerSpawns")
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	assert(#parts > 0, "[LobbyService] Workspace.Lobby.PlayerSpawns has no parts")
	spawnParts = parts
	return parts
end

function LobbyService.start()
	lobbySpawns()
end

function LobbyService.teleport(character: Model)
	local spawns = lobbySpawns()
	local spawnPart = spawns[math.random(#spawns)]
	character:WaitForChild("HumanoidRootPart")
	character:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3.5, 0)) * spawnPart.CFrame.Rotation)
end

return LobbyService
