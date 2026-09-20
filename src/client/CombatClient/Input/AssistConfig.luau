-- Description: Client-side reader for the per-player aim-assist strengths the server projects onto the player, re-reading them whenever the projection changes.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local AssistResolver = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config"):WaitForChild("AssistResolver")
)

local AssistConfig = {}

local started = false
local resolved: { [string]: any } = PlayerAssist.Defaults
local connections: { RBXScriptConnection } = {}

local function reread(folder: Folder)
	local rawValues = {}
	for _, entry in PlayerAssist.Entries do
		local value = folder:FindFirstChild(entry.Key)
		if value and value:IsA("ValueBase") then
			rawValues[entry.Key] = (value :: any).Value
		end
	end
	resolved = AssistResolver.resolve(PlayerAssist.Entries, rawValues)
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
	started = true

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
		folder.AttributeChanged:Connect(function()
			reread(folder)
		end)
	)
	reread(folder)
end

function AssistConfig.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	resolved = PlayerAssist.Defaults
	started = false
end

return AssistConfig
