-- Description: Reads the Roblox experience config snapshot, validates every declared override against its type and range, installs it into the live config tables, and restores the shipped value when an override disappears.

--!strict

local ConfigService = game:GetService("ConfigService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local LiveConfig = require(Config:WaitForChild("LiveConfig"))
local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config")
local ConfigOverrides = require(ConfigFolder:WaitForChild("ConfigOverrides"))
local ConfigRuntime = require(ConfigFolder:WaitForChild("ConfigRuntime"))

local ConfigLiveService = {}

local started = false
local snapshot: any = nil
local holdSimOverrides: (() -> boolean)? = nil
local stateFolder: Folder? = nil
local stateValue: StringValue? = nil
local revision = 0
local entries: { ConfigOverrides.Entry } = {}

local function ensureStateFolder(): Folder
	if stateFolder then
		return stateFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = LiveConfig.StateFolderName
	local value = Instance.new("StringValue")
	value.Name = "Snapshot"
	value.Value = HttpService:JSONEncode({ revision = 0, overrides = {} })
	value.Parent = folder
	folder.Parent = ReplicatedStorage
	stateFolder = folder
	stateValue = value
	return folder
end

local function shouldHold(): (boolean?, string?)
	local predicate = holdSimOverrides
	if predicate == nil then
		return false, nil
	end
	local ok, result = pcall(predicate)
	if not ok then
		return nil, `hold predicate failed: {result}`
	end
	return result == true, nil
end

local function readRawValues(): { [string]: any }?
	local current = snapshot
	if current == nil then
		return nil
	end
	local rawValues = {}
	for _, entry in entries do
		local ok, value = pcall(current.GetValue, current, entry.Key)
		if not ok then
			warn(`[ConfigLiveService] Could not read config key "{entry.Key}": {value}`)
			return nil
		end
		rawValues[entry.Key] = value
	end
	return rawValues
end

local function install(force: boolean?)
	local current = snapshot
	if current == nil then
		return
	end

	local errorState = (current :: any).Error
	if errorState ~= nil and errorState ~= Enum.ConfigSnapshotErrorState.None then
		warn(`[ConfigLiveService] Config snapshot unusable ({errorState.Name}); keeping current values`)
		return
	end

	local rawValues = readRawValues()
	if rawValues == nil then
		return
	end

	local accepted, rejected = ConfigOverrides.resolve(entries, rawValues)
	if #rejected > 0 then
		for _, rejection in rejected do
			warn(
				`[ConfigLiveService] Rejected config snapshot at "{rejection.Key}": {rejection.Reason}; keeping revision {revision}`
			)
		end
		return
	end

	local immediate, simOverrides = ConfigOverrides.partition(accepted, LiveConfig.SimCritical)
	local hold = false
	if not force then
		local result, holdError = shouldHold()
		if holdError ~= nil then
			warn(`[ConfigLiveService] {holdError}; keeping revision {revision}`)
			return
		end
		hold = result == true
	end
	if force or not hold then
		for key, value in simOverrides do
			immediate[key] = value
		end
	else
		for key, value in ConfigRuntime.activeOverrides() do
			local moduleName = ConfigOverrides.parseKey(key)
			if moduleName ~= nil and LiveConfig.SimCritical[moduleName] then
				immediate[key] = value
			end
		end
	end

	local nextRevision = revision + 1
	local encodedOk, encoded = pcall(HttpService.JSONEncode, HttpService, {
		revision = nextRevision,
		overrides = immediate,
	})
	if not encodedOk then
		warn(`[ConfigLiveService] Could not encode config revision {nextRevision}: {encoded}`)
		return
	end
	local applied, reason = ConfigRuntime.apply(immediate)
	if not applied then
		warn(`[ConfigLiveService] Rejected config revision {nextRevision}: {reason}; keeping revision {revision}`)
		return
	end
	ensureStateFolder()(stateValue :: StringValue).Value = encoded
	revision = nextRevision
end

function ConfigLiveService.releaseLatched()
	install(true)
end

local function refresh()
	local current = snapshot
	if current == nil then
		return
	end
	local ok, err = pcall(current.Refresh, current)
	if not ok then
		warn(`[ConfigLiveService] Config refresh failed: {err}`)
		return
	end
	install()
end

local acquire: () -> ()

local function scheduleRetry()
	task.delay(LiveConfig.RetrySeconds, function()
		if snapshot == nil then
			acquire()
		end
	end)
end

acquire = function()
	local ok, result = pcall(ConfigService.GetConfigAsync, ConfigService)
	if not ok or result == nil then
		warn(
			`[ConfigLiveService] Experience configs unavailable; using baked values ({if ok
				then "no snapshot"
				else result})`
		)
		scheduleRetry()
		return
	end

	snapshot = result
	local connected, connectError = pcall(function()
		result.UpdateAvailable:Connect(refresh)
	end)
	if not connected then
		warn(`[ConfigLiveService] Could not observe config updates: {connectError}`)
	end
	install()
end

function ConfigLiveService.start(context: {
	modules: { [string]: any },
	holdSimOverrides: (() -> boolean)?,
})
	if started then
		return
	end
	started = true
	holdSimOverrides = context.holdSimOverrides

	for name, moduleTable in context.modules do
		ConfigRuntime.register(name, moduleTable)
	end
	for _, entry in LiveConfig.Entries do
		local moduleName = ConfigOverrides.parseKey(entry.Key)
		if moduleName ~= nil and context.modules[moduleName] ~= nil then
			table.insert(entries, entry)
		end
	end
	ensureStateFolder()

	task.spawn(acquire)
	task.spawn(function()
		while true do
			task.wait(LiveConfig.ResyncSeconds)
			if snapshot ~= nil then
				refresh()
			end
		end
	end)
end

return ConfigLiveService
