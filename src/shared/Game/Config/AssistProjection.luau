--!strict

local PlayerAssist = require(script.Parent.Parent.Parent.Parent.Config.PlayerAssist)
local AssistResolver = require(script.Parent.AssistResolver)

-- Reads a player's projected AssistConfig folder into resolved strengths. Both
-- sides use it: the server adapter attaches the result to sim commands, the
-- client reads its own for camera assists, and both land on the same numbers
-- because the same rules run over the same projection.
--
-- Cached per folder and invalidated by comparing the revision attribute rather
-- than by connecting to it, so there is no per-player connection to clean up and
-- a folder that is destroyed simply falls out of the weak-keyed cache. Revision
-- is only ever used to detect that something changed, never as a commit barrier:
-- the whole folder is re-read on any bump.

local AssistProjection = {}

type Cached = { revision: number, resolved: { [string]: any }, strengths: { [string]: { [string]: number } } }

local cache: { [Folder]: Cached } = setmetatable({}, { __mode = "k" }) :: any

local function readFolder(folder: Folder): { [string]: any }
	local rawValues = {}
	for _, entry in PlayerAssist.Entries do
		local value = folder:FindFirstChild(entry.Key)
		if value and value:IsA("ValueBase") then
			rawValues[entry.Key] = (value :: any).Value
		end
	end
	return AssistResolver.resolve(PlayerAssist.Entries, rawValues)
end

local function entryFor(folder: Folder): Cached
	local revision = (folder:GetAttribute(PlayerAssist.RevisionAttribute) :: number?) or 0
	local cached = cache[folder]
	if cached ~= nil and cached.revision == revision then
		return cached
	end
	local fresh: Cached = { revision = revision, resolved = readFolder(folder), strengths = {} }
	cache[folder] = fresh
	return fresh
end

-- Resolved values for a folder, or the baked defaults when the projection has
-- not arrived yet.
function AssistProjection.resolved(folder: Folder?): { [string]: any }
	if folder == nil then
		return PlayerAssist.Defaults
	end
	return entryFor(folder).resolved
end

-- Every feature's effective 0-1 strength on the given device, in one table ready
-- to attach to a sim command. Zero means inert.
function AssistProjection.strengths(folder: Folder?, deviceClass: string?): { [string]: number }
	local scale = AssistResolver.scaleFor(PlayerAssist.DeviceScale, deviceClass)
	if folder == nil then
		local defaults = {}
		for _, feature in PlayerAssist.Features do
			defaults[feature] = AssistResolver.strength(PlayerAssist.Defaults, scale, feature)
		end
		return defaults
	end

	local cached = entryFor(folder)
	local key = deviceClass or "Mouse"
	local existing = cached.strengths[key]
	if existing ~= nil then
		return existing
	end
	local computed = {}
	for _, feature in PlayerAssist.Features do
		computed[feature] = AssistResolver.strength(cached.resolved, scale, feature)
	end
	cached.strengths[key] = computed
	return computed
end

function AssistProjection.strength(folder: Folder?, deviceClass: string?, feature: string): number
	return AssistProjection.strengths(folder, deviceClass)[feature] or 0
end

return AssistProjection
