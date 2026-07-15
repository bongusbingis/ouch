--!strict

local Workspace = game:GetService("Workspace")

-- Teleports characters to the Studio-authored lobby. Spawn points follow the
-- same convention as maps: invisible parts inside Workspace.Lobby.PlayerSpawns.

local LobbyService = {}

local spawnParts: { BasePart }? = nil

local function lobbySpawns(): { BasePart }
	if spawnParts then
		return spawnParts
	end
	local folder = Workspace:WaitForChild("Lobby"):WaitForChild("PlayerSpawns")
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

function LobbyService.teleport(character: Model)
	local spawns = lobbySpawns()
	local spawnPart = spawns[math.random(#spawns)]
	character:WaitForChild("HumanoidRootPart")
	character:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3.5, 0)) * spawnPart.CFrame.Rotation)
end

return LobbyService
