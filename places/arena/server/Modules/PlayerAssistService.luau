--!strict

local ConfigService = game:GetService("ConfigService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local AssistResolver = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config"):WaitForChild("AssistResolver")
)

-- Resolves each player's assist scalars through
-- ConfigService:GetConfigForPlayerAsync, so an experience config condition can
-- hold half the population at a different strength and the difference shows up
-- in telemetry.
--
-- This is deliberately not LiveConfigService. That one installs a single global
-- snapshot into the shared config tables, which by construction cannot express
-- a per-player value. Here each player gets their own resolved set, projected
-- onto value objects under their own Player so their client can read it and
-- nobody else's.
--
-- Every failure path lands on the baked defaults in Config.PlayerAssist: an
-- unavailable config service, a rejected value, or a player who left mid-resolve
-- all leave assists at their shipped strength rather than off or wild.

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

-- One value object per entry, mirroring how ConfigState projects the global set.
-- Revision is bumped last, but consumers re-read every value on any change
-- rather than trusting it as a commit barrier: attributes and children do not
-- replicate in write order.
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

-- Reads every declared key, or none: one failed read abandons the pass so a
-- partial set never replaces a good one.
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
	-- Defaults are projected first so the client always has a complete set to
	-- read, even if the config service never answers.
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

-- Resolved scalars for a player, for the sim to attach to their commands.
function PlayerAssistService.get(player: Player): { [string]: any }
	return resolvedByPlayer[player] or PlayerAssist.Defaults
end

-- Effective 0-1 strength for one feature on this player's active device.
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
