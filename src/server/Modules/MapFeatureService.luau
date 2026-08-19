--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ArenaService = require(script.Parent.ArenaService)
local MapFeatureKit = require(script.Parent.MapFeatures.MapFeatureKit)
local MapFeatureRegistry = require(script.Parent.MapFeatures.MapFeatureRegistry)

-- Drives the authored features under Workspace.Assets.Arena.Scriptables. Each
-- registered kit owns one folder there; this service discovers that folder's
-- BasePart children, keeps the list current as parts are added or removed, and
-- runs every kit from one Heartbeat.
--
-- A kit with no authored folder is simply inactive, so features can be
-- registered before the arena has them and the arena can carry folders no kit
-- claims yet.

local MapFeatureService = {}

local partsByKit: { [string]: { BasePart } } = {}
local connections: { RBXScriptConnection } = {}
local heartbeat: RBXScriptConnection? = nil
local started = false

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil or character:GetAttribute("CombatAlive") == false then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function refresh(kit: MapFeatureKit.MapFeatureKit, folder: Folder)
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	partsByKit[kit.folderName] = parts
end

-- Alive roots are resolved once per frame and shared by every kit: resolving them
-- per kit repeated the same FindFirstChild for each feature, and GetPlayers
-- allocates a fresh table on every call.
local riders: { Player } = {}
local riderRoots: { BasePart } = {}
local context: MapFeatureKit.Context = { parts = {}, now = 0, deltaTime = 0 }

local function step(deltaTime: number)
	table.clear(riders)
	table.clear(riderRoots)
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root then
			table.insert(riders, player)
			table.insert(riderRoots, root)
		end
	end

	context.now = os.clock()
	context.deltaTime = deltaTime
	for _, kit in MapFeatureRegistry.all() do
		local parts = partsByKit[kit.folderName]
		if parts == nil or #parts == 0 then
			continue
		end
		context.parts = parts
		if kit.tickWorld then
			kit.tickWorld(context)
		end
		if kit.tickPlayer == nil then
			continue
		end
		for index, player in riders do
			kit.tickPlayer(context, player, riderRoots[index])
		end
	end
end

function MapFeatureService.start()
	if started then
		return
	end
	started = true

	local scriptables = ArenaService.get().scriptables
	for _, kit in MapFeatureRegistry.all() do
		-- FindFirstChild rather than WaitForChild: a registered kit whose folder is
		-- not authored yet stays inactive instead of stalling the arena. The warning
		-- keeps a missing folder from passing silently.
		local folder = scriptables:FindFirstChild(kit.folderName)
		if folder == nil or not folder:IsA("Folder") then
			warn(`[MapFeatureService] No Scriptables.{kit.folderName} Folder authored; feature inactive`)
			continue
		end
		refresh(kit, folder)
		table.insert(
			connections,
			folder.ChildAdded:Connect(function()
				refresh(kit, folder)
			end)
		)
		table.insert(
			connections,
			folder.ChildRemoved:Connect(function()
				refresh(kit, folder)
			end)
		)
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, kit in MapFeatureRegistry.all() do
			if kit.forget then
				kit.forget(player)
			end
		end
	end)

	heartbeat = RunService.Heartbeat:Connect(step)
end

function MapFeatureService.stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(partsByKit)
	for _, kit in MapFeatureRegistry.all() do
		if kit.forget then
			kit.forget(nil)
		end
	end
	started = false
end

return MapFeatureService
