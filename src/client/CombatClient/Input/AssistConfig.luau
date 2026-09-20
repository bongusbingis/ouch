-- Description: Client-side reader for the per-player aim-assist strengths the server projects onto the player, re-reading them whenever the projection changes.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local configFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config")
local AssistResolver = require(configFolder:WaitForChild("AssistResolver"))
local AssistProjection = require(configFolder:WaitForChild("AssistProjection"))

local AssistConfig = {}

local started = false
local resolved: { [string]: any } = PlayerAssist.Defaults
local connections: { RBXScriptConnection } = {}
local lastError: string? = nil

local function reread(folder: Folder): (boolean, string?)
	local ok, reason, candidate = AssistProjection.read(folder)
	if not ok or candidate == nil then
		if reason ~= lastError then
			warn(`[AssistConfig] {reason}`)
			lastError = reason
		end
		return false, reason
	end
	if lastError ~= nil then
		warn(`[AssistConfig] recovered {folder:GetFullName()} after a valid projection`)
		lastError = nil
	end
	resolved = candidate
	return true, nil
end

function AssistConfig.strength(feature: string, deviceClass: string): number
	local scale = AssistResolver.scaleFor(PlayerAssist.DeviceScale, deviceClass)
	return AssistResolver.strength(resolved, scale, feature)
end

function AssistConfig.start()
	if started then
		return
	end

	local player = Players.LocalPlayer
	local folder = player:WaitForChild(PlayerAssist.FolderName, 10)
	assert(
		folder,
		`[AssistConfig] missing {player:GetFullName()}.{PlayerAssist.FolderName}; check PlayerConfigService projection`
	)
	assert(folder:IsA("Folder"), `[AssistConfig] {folder:GetFullName()} must be a Folder`)
	local deadline = os.clock() + 10
	for _, entry in PlayerAssist.Entries do
		if folder:FindFirstChild(entry.Key) == nil then
			local remaining = deadline - os.clock()
			if remaining > 0 then
				folder:WaitForChild(entry.Key, remaining)
			end
		end
	end
	local ok, reason = reread(folder)
	assert(ok, `[AssistConfig] {reason}`)

	local function watch(child: Instance)
		if child:IsA("ValueBase") then
			table.insert(
				connections,
				child.Changed:Connect(function()
					reread(folder)
				end)
			)
		end
	end
	for _, child in folder:GetChildren() do
		watch(child)
	end
	table.insert(
		connections,
		folder.ChildAdded:Connect(function(child)
			watch(child)
			reread(folder)
		end)
	)
	table.insert(
		connections,
		folder.ChildRemoved:Connect(function()
			reread(folder)
		end)
	)
	table.insert(
		connections,
		folder.AttributeChanged:Connect(function()
			reread(folder)
		end)
	)
	started = true
end

function AssistConfig.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	resolved = PlayerAssist.Defaults
	lastError = nil
	started = false
end

return AssistConfig
