--!strict

-- Locally samples the server-published liquid schedule. The server remains the
-- collision and elimination authority; these writes only keep this client's
-- replicated liquid geometry on the same absolute-clock pose between updates.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local RisingLiquid = require(ReplicatedStorage.Shared.Game.MapFeatures.RisingLiquid)

local RisingLiquidClient = {}

local BASE_ATTRIBUTE = "SplashdownLavaBase"
local CONFIG_ATTRIBUTE = "SplashdownLavaConfig"
local STATE_ATTRIBUTE = "SplashdownLavaState"

type State = { revision: number, active: boolean, startsAt: number, frozenAt: number? }
type Record = {
	part: BasePart,
	base: CFrame,
	config: RisingLiquid.Config,
	state: State,
}

local started = false
local records: { [BasePart]: Record } = {}
local connections: { RBXScriptConnection } = {}
local watches: { [BasePart]: { RBXScriptConnection } } = {}
local hazardWatches: { [Folder]: { RBXScriptConnection } } = {}

local function isActiveHazards(folder: Folder): boolean
	local course = folder.Parent
	return folder:IsDescendantOf(Workspace)
		and course ~= nil
		and course:IsA("Model")
		and course.Name == Splashdown.ActiveCourseName
end

local function isWatchedHazardCandidate(part: BasePart): boolean
	for folder in hazardWatches do
		if isActiveHazards(folder) and part:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function decodeConfig(value: any): RisingLiquid.Config?
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	if not ok or typeof(decoded) ~= "table" then
		return nil
	end
	local studs = decoded.studs
	local seconds = decoded.seconds
	local delaySeconds = decoded.delaySeconds
	if
		not finite(studs)
		or studs <= 0
		or not finite(seconds)
		or seconds <= 0
		or not finite(delaySeconds)
		or delaySeconds < 0
	then
		return nil
	end
	local pauses: { RisingLiquid.Pause } = {}
	if decoded.pauses ~= nil then
		if typeof(decoded.pauses) ~= "table" then
			return nil
		end
		local previous = -1
		for _, pause in decoded.pauses do
			if typeof(pause) ~= "table" or not finite(pause.height) or not finite(pause.seconds) then
				return nil
			end
			if pause.height < 0 or pause.height > studs or pause.height <= previous or pause.seconds < 0 then
				return nil
			end
			table.insert(pauses, { height = pause.height, seconds = pause.seconds })
			previous = pause.height
		end
	end
	return { studs = studs, seconds = seconds, delaySeconds = delaySeconds, pauses = pauses }
end

local function decodeState(value: any): State?
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	if not ok or typeof(decoded) ~= "table" then
		return nil
	end
	if not finite(decoded.revision) or decoded.revision < 1 or decoded.revision % 1 ~= 0 then
		return nil
	end
	if typeof(decoded.active) ~= "boolean" or not finite(decoded.startsAt) or decoded.startsAt < 0 then
		return nil
	end
	if decoded.frozenAt ~= nil and not finite(decoded.frozenAt) then
		return nil
	end
	if not decoded.active and decoded.frozenAt == nil then
		return nil
	end
	return {
		revision = decoded.revision,
		active = decoded.active,
		startsAt = decoded.startsAt,
		frozenAt = decoded.frozenAt,
	}
end

local function clear(part: BasePart)
	local record = records[part]
	if record == nil then
		return
	end
	records[part] = nil
end

local function unwatch(part: BasePart)
	clear(part)
	local watched = watches[part]
	if watched == nil then
		return
	end
	watches[part] = nil
	for _, connection in watched do
		connection:Disconnect()
	end
end

local function refresh(part: BasePart)
	if part:GetAttribute("RisingLiquid") ~= true then
		clear(part)
		return
	end
	local base = part:GetAttribute(BASE_ATTRIBUTE)
	local config = decodeConfig(part:GetAttribute(CONFIG_ATTRIBUTE))
	local state = decodeState(part:GetAttribute(STATE_ATTRIBUTE))
	if typeof(base) ~= "CFrame" or config == nil or state == nil then
		clear(part)
		return
	end
	local record = records[part]
	if record then
		if state.revision < record.state.revision then
			return
		end
		record.base = base
		record.config = config
		record.state = state
		return
	end
	records[part] = { part = part, base = base, config = config, state = state }
end

local function watch(part: BasePart)
	if watches[part] ~= nil then
		return
	end
	local watched: { RBXScriptConnection } = {}
	watches[part] = watched
	for _, attribute in { BASE_ATTRIBUTE, CONFIG_ATTRIBUTE, STATE_ATTRIBUTE, "RisingLiquid" } do
		table.insert(
			watched,
			part:GetAttributeChangedSignal(attribute):Connect(function()
				if part:GetAttribute("RisingLiquid") == true then
					refresh(part)
				else
					clear(part)
				end
			end)
		)
	end
	table.insert(
		watched,
		part.AncestryChanged:Connect(function(_, parent)
			task.defer(function()
				if not part:IsDescendantOf(Workspace) then
					unwatch(part)
				end
			end)
		end)
	)
	refresh(part)
end

local function unwatchHazards(folder: Folder)
	local watched = hazardWatches[folder]
	if watched == nil then
		return
	end
	hazardWatches[folder] = nil
	for _, connection in watched do
		connection:Disconnect()
	end
end

local function watchHazards(folder: Folder)
	if hazardWatches[folder] ~= nil then
		return
	end
	local watched: { RBXScriptConnection } = {}
	hazardWatches[folder] = watched
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			watch(descendant)
		end
	end
	table.insert(
		watched,
		folder.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				watch(descendant)
			end
		end)
	)
	table.insert(
		watched,
		folder.DescendantRemoving:Connect(function(descendant)
			task.defer(function()
				if descendant:IsA("BasePart") then
					if not isWatchedHazardCandidate(descendant) then
						unwatch(descendant)
					end
					return
				end
				for _, nested in descendant:GetDescendants() do
					if nested:IsA("BasePart") and not isWatchedHazardCandidate(nested) then
						unwatch(nested)
					end
				end
			end)
		end)
	)
	table.insert(
		watched,
		folder.AncestryChanged:Connect(function(_, parent)
			task.defer(function()
				if not isActiveHazards(folder) then
					unwatchHazards(folder)
					for _, nested in folder:GetDescendants() do
						if nested:IsA("BasePart") and not isWatchedHazardCandidate(nested) then
							unwatch(nested)
						end
					end
				end
			end)
		end)
	)
end

local function watchCourse(course: Instance)
	if not course:IsA("Model") or course.Name ~= Splashdown.ActiveCourseName then
		return
	end
	local hazards = course:FindFirstChild("Hazards")
	if hazards and hazards:IsA("Folder") then
		watchHazards(hazards)
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for part, record in records do
		if not part:IsDescendantOf(Workspace) then
			clear(part)
			continue
		end
		local sampleTime = if record.state.active then now else record.state.frozenAt
		if sampleTime == nil then
			continue
		end
		local height = RisingLiquid.heightAt(math.max(sampleTime - record.state.startsAt, 0), record.config)
		local target = record.base + Vector3.new(0, height, 0)
		if (part.CFrame.Position - target.Position).Magnitude > 1e-4 then
			part.CFrame = target
		end
	end
end

function RisingLiquidClient.start()
	if started then
		return
	end
	started = true
	-- Do not enumerate every map part at startup. Only a current active course
	-- can own a rising liquid, and its Hazards folder owns bounded candidate
	-- watchers so marker attributes may arrive after the BasePart streams in.
	local existing = Workspace:FindFirstChild(Splashdown.ActiveCourseName, true)
	if existing then
		watchCourse(existing)
	end
	table.insert(
		connections,
		Workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Model") then
				watchCourse(descendant)
			elseif descendant:IsA("Folder") and descendant.Name == "Hazards" then
				local parent = descendant.Parent
				if parent and parent:IsA("Model") and parent.Name == Splashdown.ActiveCourseName then
					watchHazards(descendant)
				end
			end
		end)
	)
	table.insert(connections, RunService.PreSimulation:Connect(step))
	table.insert(connections, RunService.PreRender:Connect(step))
end

function RisingLiquidClient.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	local watchedParts = {}
	for part in watches do
		table.insert(watchedParts, part)
	end
	for _, part in watchedParts do
		unwatch(part)
	end
	local watchedHazards = {}
	for folder in hazardWatches do
		table.insert(watchedHazards, folder)
	end
	for _, folder in watchedHazards do
		unwatchHazards(folder)
	end
	started = false
end

return RisingLiquidClient
