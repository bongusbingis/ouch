-- Name: MapFeatureService.luau
-- Author: Jack C.
-- Description: Drives every authored arena map feature from one heartbeat, discovering each kit's folder under the arena scriptables, keeping its parts current as they change, and dispatching the per-player and per-world hooks.
-- Created: 2026-07-14

--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ArenaService = require(script.Parent.ArenaService)
local MapFeatureKit = require(script.Parent.MapFeatures.MapFeatureKit)
local MapFeatureRegistry = require(script.Parent.MapFeatures.MapFeatureRegistry)

local MapFeatureService = {}

local partsByKit: { [string]: { Instance } } = {}
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
	local collected = {}
	local className = kit.instanceClass or "BasePart"
	for _, child in folder:GetChildren() do
		if child:IsA(className) then
			table.insert(collected, child)
		end
	end
	partsByKit[kit.folderName] = collected
	if #collected == 0 and kit.forget then
		kit.forget(nil)
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

	local scriptables = ArenaService.get().scriptables
	for _, kit in MapFeatureRegistry.all() do
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
