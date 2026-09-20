-- Description: Reads and writes the per-player aim-assist projection, turning resolved assist scalars into replicated values and back for the client.

--!strict

local PlayerAssist = require(script.Parent.Parent.Parent.Parent.Config.PlayerAssist)
local AssistResolver = require(script.Parent.AssistResolver)

local AssistProjection = {}

type Cached = { revision: number, resolved: { [string]: any }, strengths: { [string]: { [string]: number } } }

local cache: { [Folder]: Cached } = setmetatable({}, { __mode = "k" }) :: any

function AssistProjection.read(folder: Folder): (boolean, string?, { [string]: any }?)
	local rawValues: { [string]: any } = {}
	for _, entry in PlayerAssist.Entries do
		local value = folder:FindFirstChild(entry.Key)
		local className = if entry.Type == "boolean" then "BoolValue" else "NumberValue"
		if value == nil or not value:IsA(className) then
			local actual = if value == nil then "missing" else value.ClassName
			return false,
				`{folder:GetFullName()}.{entry.Key}: expected {className}; received {actual}; check PlayerConfigService projection`,
				nil
		end
		rawValues[entry.Key] = (value :: any).Value
	end
	local ok, reason, resolved = AssistResolver.resolve(PlayerAssist.Entries, rawValues)
	if not ok then
		return false, `{folder:GetFullName()}.{reason}; correct the projected value`, nil
	end
	return true, nil, resolved
end

local function entryFor(folder: Folder): (boolean, string?, Cached?)
	local revision = folder:GetAttribute(PlayerAssist.RevisionAttribute)
	if typeof(revision) ~= "number" or revision ~= revision or revision < 0 or revision == math.huge then
		return false,
			`{folder:GetFullName()}.{PlayerAssist.RevisionAttribute}: expected finite nonnegative number; received {tostring(
				revision
			)}`,
			nil
	end
	local cached = cache[folder]
	local ok, reason, resolved = AssistProjection.read(folder)
	if not ok or resolved == nil then
		return false, reason, nil
	end
	if cached ~= nil and cached.revision == revision then
		local unchanged = true
		for _, entry in PlayerAssist.Entries do
			if cached.resolved[entry.Key] ~= resolved[entry.Key] then
				unchanged = false
				break
			end
		end
		if unchanged then
			return true, nil, cached
		end
	end
	local fresh: Cached = { revision = revision, resolved = resolved, strengths = {} }
	cache[folder] = fresh
	return true, nil, fresh
end

function AssistProjection.resolved(folder: Folder?): (boolean, string?, { [string]: any }?)
	if folder == nil then
		return true, nil, PlayerAssist.Defaults
	end
	local ok, reason, cached = entryFor(folder)
	return ok, reason, if cached then cached.resolved else nil
end

function AssistProjection.strengths(folder: Folder?, deviceClass: string?): (boolean, string?, { [string]: number }?)
	local scale = AssistResolver.scaleFor(PlayerAssist.DeviceScale, deviceClass)
	if folder == nil then
		local defaults = {}
		for _, feature in PlayerAssist.Features do
			defaults[feature] = AssistResolver.strength(PlayerAssist.Defaults, scale, feature)
		end
		return true, nil, defaults
	end

	local ok, reason, cached = entryFor(folder)
	if not ok or cached == nil then
		return false, reason, nil
	end
	local key = deviceClass or "Mouse"
	local existing = cached.strengths[key]
	if existing ~= nil then
		return true, nil, existing
	end
	local computed = {}
	for _, feature in PlayerAssist.Features do
		computed[feature] = AssistResolver.strength(cached.resolved, scale, feature)
	end
	cached.strengths[key] = computed
	return true, nil, computed
end

function AssistProjection.strength(folder: Folder?, deviceClass: string?, feature: string): (boolean, string?, number?)
	local ok, reason, strengths = AssistProjection.strengths(folder, deviceClass)
	return ok, reason, if strengths then strengths[feature] else nil
end

return AssistProjection
