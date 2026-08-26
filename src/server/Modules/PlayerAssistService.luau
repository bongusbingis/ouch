-- Name: PlayerAssistService.luau
-- Author: Jack C.
-- Description: Resolves each player's aim-assist scalars from config and device class and projects them onto the player so both the sim and the client read the same values.
-- Created: 2026-08-19

--!strict

local ConfigService = game:GetService("ConfigService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local AssistResolver = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config"):WaitForChild("AssistResolver")
)

local PlayerAssistService = {}

local started = false
local resolvedByPlayer: { [Player]: { [string]: any } } = {}
local snapshotsByPlayer: { [Player]: any } = {}

local function folderFor(player: Player): Folder
	local existing = player:FindFirstChild(PlayerAssist.FolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = PlayerAssist.FolderName
	folder:SetAttribute(PlayerAssist.RevisionAttribute, 0)
	folder.Parent = player
	return folder
end

local function project(player: Player, resolved: { [string]: any })
	local folder = folderFor(player)
	for _, entry in PlayerAssist.Entries do
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
	local revision = (folder:GetAttribute(PlayerAssist.RevisionAttribute) :: number?) or 0
	folder:SetAttribute(PlayerAssist.RevisionAttribute, revision + 1)
end

local function apply(player: Player, rawValues: { [string]: any })
	if player.Parent ~= Players then
		return
	end
	local resolved = AssistResolver.resolve(PlayerAssist.Entries, rawValues)
	resolvedByPlayer[player] = resolved
	project(player, resolved)
end

local function readValues(snapshot: any): { [string]: any }?
	local rawValues = {}
	for _, entry in PlayerAssist.Entries do
		local ok, value = pcall(snapshot.GetValue, snapshot, entry.Key)
		if not ok then
			warn(`[PlayerAssistService] Could not read "{entry.Key}": {value}`)
			return nil
		end
		rawValues[entry.Key] = value
	end
	return rawValues
end

local function refresh(player: Player)
	local snapshot = snapshotsByPlayer[player]
	if snapshot == nil then
		return
	end
	local errorState = (snapshot :: any).Error
	if errorState ~= nil and errorState ~= Enum.ConfigSnapshotErrorState.None then
		warn(`[PlayerAssistService] Snapshot unusable for {player.Name}; keeping current values`)
		return
	end
	local rawValues = readValues(snapshot)
	if rawValues then
		apply(player, rawValues)
	end
end

local function acquire(player: Player)
	if player.Parent ~= Players then
		return
	end
	apply(player, {})

	local ok, snapshot = pcall(ConfigService.GetConfigForPlayerAsync, ConfigService, player)
	if not ok or snapshot == nil or player.Parent ~= Players then
		if player.Parent == Players then
			task.delay(PlayerAssist.RetrySeconds, function()
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
		warn(`[PlayerAssistService] Could not observe assist updates for {player.Name}: {connectError}`)
	end
	refresh(player)
end

function PlayerAssistService.get(player: Player): { [string]: any }
	return resolvedByPlayer[player] or PlayerAssist.Defaults
end

function PlayerAssistService.strength(player: Player, feature: string): number
	local deviceClass = player:GetAttribute("DeviceClass") :: string?
	local scale = AssistResolver.scaleFor(PlayerAssist.DeviceScale, deviceClass)
	return AssistResolver.strength(PlayerAssistService.get(player), scale, feature)
end

function PlayerAssistService.start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(function(player)
		task.spawn(acquire, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		resolvedByPlayer[player] = nil
		snapshotsByPlayer[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(acquire, player)
	end
end

return PlayerAssistService
