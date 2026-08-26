-- Name: ConfigReplication.luau
-- Author: Jack C.
-- Description: Client half of live config: reads the replicated override projection, re-validates every value, and applies it onto the local config tables as the revision changes.
-- Created: 2026-08-18

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LiveConfig"))
local ConfigFolder = script.Parent.Parent:WaitForChild("Config")
local ConfigOverrides = require(ConfigFolder:WaitForChild("ConfigOverrides"))
local ConfigRuntime = require(ConfigFolder:WaitForChild("ConfigRuntime"))

local ConfigReplication = {}

local started = false

local function applyProjection(folder: Folder)
	local rawValues = {}
	for _, entry in LiveConfig.Entries do
		local child = folder:FindFirstChild(ConfigOverrides.projectedName(entry.Key))
		if child and child:IsA("ValueBase") then
			rawValues[entry.Key] = (child :: any).Value
		end
	end
	local accepted = ConfigOverrides.resolve(LiveConfig.Entries, rawValues)
	ConfigRuntime.apply(accepted)
end

function ConfigReplication.startClient(modules: { [string]: any })
	if started then
		return
	end
	started = true

	for name, moduleTable in modules do
		ConfigRuntime.register(name, moduleTable)
	end

	local folder = ReplicatedStorage:WaitForChild(LiveConfig.StateFolderName)
	assert(folder:IsA("Folder"), `[ConfigReplication] ReplicatedStorage.{LiveConfig.StateFolderName} must be a Folder`)

	local function reapply()
		applyProjection(folder)
	end

	local function watchChild(child: Instance)
		child.Changed:Connect(reapply)
		reapply()
	end

	folder.AttributeChanged:Connect(reapply)
	folder.ChildAdded:Connect(watchChild)
	folder.ChildRemoved:Connect(reapply)
	for _, child in folder:GetChildren() do
		child.Changed:Connect(reapply)
	end
	applyProjection(folder)
end

return ConfigReplication
