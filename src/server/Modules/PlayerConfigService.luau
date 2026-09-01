-- Name: PlayerConfigService.luau
-- Author: Jack C.
-- Description: Generic per-player AB config engine. Resolves each registered schema from the player's Roblox experience-config snapshot and projects it onto a Player-owned folder, so the sim and client read the same validated values. Aim assist (Config.PlayerAssist) is one schema; a new per-player experiment is a new schema plus its own consumer, with no change here.
-- Created: 2026-08-19

--!strict

local ConfigService = game:GetService("ConfigService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfigResolver = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Config")
		:WaitForChild("PlayerConfigResolver")
)

export type Schema = {
	FolderName: string,
	RevisionAttribute: string,
	Entries: { PlayerConfigResolver.Entry },
}

local PlayerConfigService = {}

local started = false
local schemas: { Schema } = {}
local retrySeconds = 30
local snapshotsByPlayer: { [Player]: any } = {}

local function folderFor(player: Player, schema: Schema): Folder
	local existing = player:FindFirstChild(schema.FolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = schema.FolderName
	folder:SetAttribute(schema.RevisionAttribute, 0)
	folder.Parent = player
	return folder
end

local function project(player: Player, schema: Schema, resolved: { [string]: any })
	local folder = folderFor(player, schema)
	for _, entry in schema.Entries do
		local className = if entry.Type == "boolean" then "BoolValue" else "NumberValue"
		local existing = folder:FindFirstChild(entry.Key)
		if existing and not existing:IsA(className) then
			existing:Destroy()
			existing = nil
		end
		if existing == nil then
			existing = Instance.new(className);
			(existing :: any).Name = entry.Key;
			(existing :: any).Parent = folder
		end
		(existing :: any).Value = resolved[entry.Key]
	end
	local revision = (folder:GetAttribute(schema.RevisionAttribute) :: number?) or 0
	folder:SetAttribute(schema.RevisionAttribute, revision + 1)
end

local function readValues(snapshot: any, schema: Schema): { [string]: any }?
	local rawValues = {}
	for _, entry in schema.Entries do
		local ok, value = pcall(snapshot.GetValue, snapshot, entry.Key)
		if not ok then
			warn(`[PlayerConfigService] Could not read "{entry.Key}": {value}`)
			return nil
		end
		rawValues[entry.Key] = value
	end
	return rawValues
end

local function apply(player: Player, snapshot: any?)
	if player.Parent ~= Players then
		return
	end
	for _, schema in schemas do
		local rawValues: { [string]: any } = {}
		if snapshot ~= nil then
			local read = readValues(snapshot, schema)
			if read == nil then
				continue
			end
			rawValues = read
		end
		project(player, schema, PlayerConfigResolver.resolve(schema.Entries, rawValues))
	end
end

local function refresh(player: Player)
	local snapshot = snapshotsByPlayer[player]
	if snapshot == nil then
		return
	end
	local errorState = (snapshot :: any).Error
	if errorState ~= nil and errorState ~= Enum.ConfigSnapshotErrorState.None then
		warn(`[PlayerConfigService] Snapshot unusable for {player.Name}; keeping current values`)
		return
	end
	apply(player, snapshot)
end

local function acquire(player: Player)
	if player.Parent ~= Players then
		return
	end
	apply(player, nil)

	local ok, snapshot = pcall(ConfigService.GetConfigForPlayerAsync, ConfigService, player)
	if not ok or snapshot == nil or player.Parent ~= Players then
		if player.Parent == Players then
			task.delay(retrySeconds, function()
				if snapshotsByPlayer[player] == nil then
					acquire(player)
				end
			end)
		end
		return
	end

	snapshotsByPlayer[player] = snapshot
	local connected, connectError = pcall(function()
		snapshot.UpdateAvailable:Connect(function()
			pcall(snapshot.Refresh, snapshot)
			refresh(player)
		end)
	end)
	if not connected then
		warn(`[PlayerConfigService] Could not observe config updates for {player.Name}: {connectError}`)
	end
	refresh(player)
end

function PlayerConfigService.start(context: {
	schemas: { Schema },
	retrySeconds: number?,
})
	if started then
		return
	end
	started = true
	schemas = context.schemas
	retrySeconds = context.retrySeconds or 30

	Players.PlayerAdded:Connect(function(player)
		task.spawn(acquire, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		snapshotsByPlayer[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(acquire, player)
	end
end

return PlayerConfigService
