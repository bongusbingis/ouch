-- Description: Drives every authored map feature from one heartbeat, discovering each kit's folder under every tagged Scriptables root -- the arena's own and any instantiated Splashdown course -- keeping its parts current as roots and children change, and dispatching the per-player and per-world hooks.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ScriptableRoots = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ScriptableRoots")
)
local MapFeatureKit = require(script.Parent.MapFeatures.MapFeatureKit)
local MapFeatureRegistry = require(script.Parent.MapFeatures.MapFeatureRegistry)

local MapFeatureService = {}

type RootState = {
	connections: { RBXScriptConnection },
	folders: { [string]: Folder },
}

local partsByKit: { [string]: { Instance } } = {}
local roots: { [Instance]: RootState } = {}
local connections: { RBXScriptConnection } = {}
local unwatch: (() -> ())? = nil
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

local function rebuild(kit: MapFeatureKit.MapFeatureKit)
	local collected = {}
	local className = kit.instanceClass or "BasePart"
	for _, state in roots do
		local folder = state.folders[kit.folderName]
		if folder == nil then
			continue
		end
		for _, child in folder:GetChildren() do
			if child:IsA(className) then
				table.insert(collected, child)
			end
		end
	end
	partsByKit[kit.folderName] = collected
	if #collected == 0 then
		-- Several kits share Rotating, but the folder has only one listener.
		-- Unloading its last group must release every kit's state/constraints.
		for _, sibling in MapFeatureRegistry.all() do
			if sibling.folderName == kit.folderName and sibling.forget then
				sibling.forget(nil)
			end
		end
	end
end

local function attachFolder(state: RootState, kit: MapFeatureKit.MapFeatureKit, folder: Folder)
	if state.folders[kit.folderName] ~= nil then
		return
	end
	state.folders[kit.folderName] = folder
	table.insert(
		state.connections,
		folder.ChildAdded:Connect(function()
			rebuild(kit)
		end)
	)
	table.insert(
		state.connections,
		folder.ChildRemoved:Connect(function()
			rebuild(kit)
		end)
	)
	rebuild(kit)
end

local function addRoot(root: Instance)
	if roots[root] then
		return
	end
	local state: RootState = { connections = {}, folders = {} }
	roots[root] = state
	for _, kit in MapFeatureRegistry.all() do
		local folder = root:FindFirstChild(kit.folderName)
		if folder and folder:IsA("Folder") then
			attachFolder(state, kit, folder)
		end
	end
	table.insert(
		state.connections,
		root.ChildAdded:Connect(function(child)
			if not child:IsA("Folder") then
				return
			end
			for _, kit in MapFeatureRegistry.all() do
				if kit.folderName == child.Name then
					attachFolder(state, kit, child)
				end
			end
		end)
	)
end

local function removeRoot(root: Instance)
	local state = roots[root]
	if state == nil then
		return
	end
	roots[root] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	for _, kit in MapFeatureRegistry.all() do
		if state.folders[kit.folderName] then
			rebuild(kit)
		end
	end
end

local riders: { Player } = {}
local riderRoots: { BasePart } = {}
local context: MapFeatureKit.Context = { instances = {}, now = 0, deltaTime = 0 }

local function step(deltaTime: number)
	table.clear(riders)
	table.clear(riderRoots)
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root then
			table.insert(riders, player)
			table.insert(riderRoots, root)
		else
			for _, kit in MapFeatureRegistry.all() do
				if kit.forget then
					kit.forget(player)
				end
			end
		end
	end

	context.now = os.clock()
	context.deltaTime = deltaTime
	for _, kit in MapFeatureRegistry.all() do
		local instances = partsByKit[kit.folderName]
		if instances == nil or #instances == 0 then
			continue
		end
		context.instances = instances
		if kit.tickWorld then
			kit.tickWorld(context)
		end
		if kit.tickPlayer == nil then
			continue
		end
		for index, player in riders do
			if aliveRoot(player) == riderRoots[index] then
				kit.tickPlayer(context, player, riderRoots[index])
			elseif kit.forget then
				kit.forget(player)
			end
		end
	end
end

function MapFeatureService.start()
	if started then
		return
	end
	started = true

	unwatch = ScriptableRoots.watch(addRoot, removeRoot)

	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			for _, kit in MapFeatureRegistry.all() do
				if kit.forget then
					kit.forget(player)
				end
			end
		end)
	)

	heartbeat = RunService.Heartbeat:Connect(step)
end

function MapFeatureService.stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if unwatch then
		unwatch()
		unwatch = nil
	end
	for root in roots do
		removeRoot(root)
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
