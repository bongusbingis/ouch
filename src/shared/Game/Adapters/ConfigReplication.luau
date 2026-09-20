-- Description: Client half of live config: reads the replicated override projection, re-validates every value, and applies it onto the local config tables as the revision changes.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LiveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LiveConfig"))
local ConfigFolder = script.Parent.Parent:WaitForChild("Config")
local ConfigOverrides = require(ConfigFolder:WaitForChild("ConfigOverrides"))
local ConfigRuntime = require(ConfigFolder:WaitForChild("ConfigRuntime"))

local ConfigReplication = {}

local started = false

function ConfigReplication.startClient(modules: { [string]: any })
	if started then
		return
	end
	started = true

	for name, moduleTable in modules do
		ConfigRuntime.register(name, moduleTable)
	end

	local folder = ReplicatedStorage:WaitForChild(LiveConfig.StateFolderName, 10)
	assert(
		folder and folder:IsA("Folder"),
		`[ConfigReplication] ReplicatedStorage.{LiveConfig.StateFolderName} must be a Folder`
	)
	local value = folder:WaitForChild("Snapshot", 10)
	assert(
		value and value:IsA("StringValue"),
		`[ConfigReplication] ReplicatedStorage.{LiveConfig.StateFolderName}.Snapshot must be a StringValue`
	)
	local scopedEntries: { ConfigOverrides.Entry } = {}
	for _, entry in LiveConfig.Entries do
		local moduleName = ConfigOverrides.parseKey(entry.Key)
		if moduleName ~= nil and modules[moduleName] ~= nil then
			table.insert(scopedEntries, entry)
		end
	end
	local revision = -1

	local function reapply()
		local decodedOk, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
		if not decodedOk then
			warn(
				`[ConfigReplication] ReplicatedStorage.{LiveConfig.StateFolderName}.Snapshot: malformed JSON: {decoded}; keeping revision {revision}`
			)
			return
		end
		local nextRevision, accepted, reason = ConfigOverrides.validateSnapshot(scopedEntries, decoded, revision)
		if nextRevision == nil or accepted == nil then
			warn(
				`[ConfigReplication] ReplicatedStorage.{LiveConfig.StateFolderName}.Snapshot: {reason}; keeping revision {revision}`
			)
			return
		end
		local applied, applyReason = ConfigRuntime.apply(accepted)
		if not applied then
			warn(
				`[ConfigReplication] ReplicatedStorage.{LiveConfig.StateFolderName}.Snapshot: {applyReason}; keeping revision {revision}`
			)
			return
		end
		revision = nextRevision
	end

	value:GetPropertyChangedSignal("Value"):Connect(reapply)
	reapply()
end

return ConfigReplication
