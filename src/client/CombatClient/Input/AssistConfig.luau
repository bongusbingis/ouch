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
	started = true

	local folder = Players.LocalPlayer:WaitForChild(PlayerAssist.FolderName)
	assert(folder:IsA("Folder"), "[AssistConfig] Player.AssistConfig must be a Folder")

	local function watch(child: Instance)
		if child:IsA("ValueBase") then
			child.Changed:Connect(function()
				reread(folder)
			end)
		end
	end
	for _, child in folder:GetChildren() do
		watch(child)
	end
	folder.ChildAdded:Connect(function(child)
		watch(child)
		reread(folder)
	end)
	folder.AttributeChanged:Connect(function()
		reread(folder)
	end)
	reread(folder)
end

return AssistConfig
