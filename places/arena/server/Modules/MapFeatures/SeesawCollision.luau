-- Collision masks for physical seesaws. Character masks mirror their original masks.
--!strict
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Collision = {}
Collision.PLANK_GROUP = "SeesawPlanks"

local sourceFor: { [string]: string } = {}
local watched: { [Player]: { RBXScriptConnection } } = {}
local characters: { [Model]: { connection: RBXScriptConnection, originals: { [BasePart]: string } } } = {}
local playerAdded: RBXScriptConnection? = nil
local playerRemoving: RBXScriptConnection? = nil

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

local function refresh()
	register(Collision.PLANK_GROUP)
	for _, item in PhysicsService:GetRegisteredCollisionGroups() do
		local other = item.name
		PhysicsService:CollisionGroupSetCollidable(Collision.PLANK_GROUP, other, sourceFor[other] ~= nil)
	end
	for characterGroup, source in sourceFor do
		for _, item in PhysicsService:GetRegisteredCollisionGroups() do
			local other = item.name
			if other ~= Collision.PLANK_GROUP then
				PhysicsService:CollisionGroupSetCollidable(
					characterGroup,
					other,
					PhysicsService:CollisionGroupsAreCollidable(source, sourceFor[other] or other)
				)
			end
		end
	end
end

local function groupFor(source: string): string
	if sourceFor[source] then
		-- Source names cannot equal our generated names in authored content.
		return source
	end
	local name = "SeesawCharacter_" .. source
	register(name)
	sourceFor[name] = source
	refresh()
	return name
end

local function detachCharacter(character: Model)
	local state = characters[character]
	if state == nil then
		return
	end
	characters[character] = nil
	state.connection:Disconnect()
	for part, original in state.originals do
		if part.Parent then
			part.CollisionGroup = original
		end
	end
end

function Collision.configureCharacter(character: Model)
	if characters[character] then
		return
	end
	local originals: { [BasePart]: string } = {}
	local function configure(part: BasePart)
		if originals[part] then
			return
		end
		local original = part.CollisionGroup
		originals[part] = original
		part.CollisionGroup = groupFor(original)
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			configure(descendant)
		end
	end
	local connection = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			configure(descendant)
		end
	end)
	characters[character] = { connection = connection, originals = originals }
end

local function watchPlayer(player: Player)
	if watched[player] then
		return
	end
	watched[player] = {
		player.CharacterAdded:Connect(Collision.configureCharacter),
		player.CharacterRemoving:Connect(detachCharacter),
	}
	if player.Character then
		Collision.configureCharacter(player.Character)
	end
end

function Collision.start()
	if playerAdded then
		refresh() -- Include collision groups registered after initial setup.
		return
	end
	register(Collision.PLANK_GROUP)
	groupFor("Default")
	playerAdded = Players.PlayerAdded:Connect(watchPlayer)
	playerRemoving = Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			detachCharacter(player.Character)
		end
		local connections = watched[player]
		if connections then
			for _, connection in connections do
				connection:Disconnect()
			end
			watched[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	refresh()
end

function Collision.stop()
	if playerAdded then
		playerAdded:Disconnect()
		playerAdded = nil
	end
	if playerRemoving then
		playerRemoving:Disconnect()
		playerRemoving = nil
	end
	for player, connections in watched do
		for _, connection in connections do
			connection:Disconnect()
		end
		watched[player] = nil
	end
	for character in characters do
		detachCharacter(character)
	end
end

return Collision
