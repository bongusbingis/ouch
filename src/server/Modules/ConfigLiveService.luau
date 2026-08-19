--!strict

local ConfigService = game:GetService("ConfigService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local LiveConfig = require(Config:WaitForChild("LiveConfig"))
local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config")
local ConfigOverrides = require(ConfigFolder:WaitForChild("ConfigOverrides"))
local ConfigRuntime = require(ConfigFolder:WaitForChild("ConfigRuntime"))

-- Reads Roblox experience configs and installs the validated overrides declared
-- in Config.LiveConfig, then mirrors exactly the active set to clients through
-- ReplicatedStorage.ConfigState.
--
-- Every engine call is guarded: if ConfigService never loads, stops responding,
-- or returns an unusable snapshot, the game keeps running on the values baked
-- into src/config and simply retries. A resync is all-or-nothing so a partial
-- read can never install a half-applied set.
--
-- Overrides for modules the deterministic sim reads are held at their current
-- values while a match is running and adopted at the next match boundary, so
-- the server never changes combat constants underneath a running match.

local ConfigLiveService = {}

local started = false
local snapshot: any = nil
local holdSimOverrides: (() -> boolean)? = nil
local stateFolder: Folder? = nil
local revision = 0

-- One value object per active override, rather than attributes: server-authority
-- replication caps an instance's total attribute payload at 1024 bytes, which 50
-- keys blow straight through, and it replicates a changed value property as a
-- small typed delta. A key with no override has no child at all, which is how
-- absence stays distinguishable from a legitimate value of 0.
--
-- revision is a single attribute bumped last, so a client reacting to it reads a
-- fully written set. This is the commit pattern ModeVoteState uses.
local VALUE_CLASS: { [string]: string } = {
	number = "NumberValue",
	boolean = "BoolValue",
	string = "StringValue",
}

local function ensureStateFolder(): Folder
	if stateFolder then
		return stateFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = LiveConfig.StateFolderName
	folder:SetAttribute(LiveConfig.RevisionAttribute, revision)
	folder.Parent = ReplicatedStorage
	stateFolder = folder
	return folder
end

local function publish()
	local folder = ensureStateFolder()
	local active = ConfigRuntime.activeOverrides()
	for _, entry in LiveConfig.Entries do
		local name = ConfigOverrides.projectedName(entry.Key)
		local existing = folder:FindFirstChild(name)
		local value = active[entry.Key]
		if value == nil then
			if existing then
				existing:Destroy()
			end
		else
			local className = VALUE_CLASS[entry.Type]
			if existing and not existing:IsA(className) then
				existing:Destroy()
				existing = nil
			end
			if existing == nil then
				existing = Instance.new(className);
				(existing :: any).Name = name;
				(existing :: any).Parent = folder
			end
			(existing :: any).Value = value
		end
	end
	revision += 1
	folder:SetAttribute(LiveConfig.RevisionAttribute, revision)
end

local function shouldHold(): boolean
	local predicate = holdSimOverrides
	if predicate == nil then
		return false
	end
	local ok, result = pcall(predicate)
	return ok and result == true
end

-- Reads every declared key, or nothing at all: a single failed read aborts the
-- resync so the currently applied set survives a transient outage untouched.
local function readRawValues(): { [string]: any }?
	local current = snapshot
	if current == nil then
		return nil
	end
	local rawValues = {}
	for _, entry in LiveConfig.Entries do
		local ok, value = pcall(current.GetValue, current, entry.Key)
		if not ok then
			warn(`[ConfigLiveService] Could not read config key "{entry.Key}": {value}`)
			return nil
		end
		rawValues[entry.Key] = value
	end
	return rawValues
end

-- Installs the current snapshot. Overrides for sim-critical modules are applied
-- only when the caller forces it or no match is running; otherwise the values
-- already in force are pinned so a match never changes constants underneath a
-- predicting client.
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

	local accepted, rejected = ConfigOverrides.resolve(LiveConfig.Entries, rawValues)
	for _, rejection in rejected do
		warn(`[ConfigLiveService] Ignored config key "{rejection.Key}": {rejection.Reason}`)
	end

	local immediate, simOverrides = ConfigOverrides.partition(accepted, LiveConfig.SimCritical)
	if force or not shouldHold() then
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

	ConfigRuntime.apply(immediate)
	publish()
end

-- Adopts the sim overrides held back during a match. Re-reads the snapshot so a
-- key deleted mid-match is reverted at the boundary too.
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
