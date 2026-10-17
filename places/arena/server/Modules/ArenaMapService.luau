-- Description: Owns which arena map is live. Maps wait pre-validated in ServerStorage.ArenaMaps; a ballot winner is swapped in by parking the live interior and moving the staged one under the permanent Workspace.Assets.Arena root, then re-resolving the arena, rebinding the ball supply and re-routing players. A map that fails validation is never offered, and a failed swap reverts so play continues.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local ArenaMaps = require(Config:WaitForChild("Gameplay"):WaitForChild("ArenaMaps"))
local Combat = require(Config:WaitForChild("Gameplay"):WaitForChild("Combat"))
local ScriptableRoots = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ScriptableRoots")
)

local ArenaService = require(script.Parent.ArenaService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local BallService = require(script.Parent.BallService)
local MatchService = require(script.Parent.MatchService)
local VenueService = require(script.Parent.VenueService)

local ArenaMapService = {}

local MAPS_FOLDER_NAME = "ArenaMaps"
local MAP_ID_ATTRIBUTE = "ArenaMapId"
local STREAM_TIMEOUT_SECONDS = 2

local currentId: string = ArenaMaps.DefaultMapId
local started = false
-- mapId -> Scriptables audit failure, filled once by start() so ballots stay cheap.
local auditFailures: { [string]: string } = {}

local function mapsFolder(create: boolean): Folder?
	local existing = ServerStorage:FindFirstChild(MAPS_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if not create then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = MAPS_FOLDER_NAME
	folder.Parent = ServerStorage
	return folder
end

local function stagedFolder(mapId: string): Folder?
	local definition = ArenaMaps.Maps[mapId]
	local folder = mapsFolder(false)
	local staged = if definition and folder then folder:FindFirstChild(definition.Template) else nil
	return if staged and staged:IsA("Folder") then staged else nil
end

local function moveChildren(from: Instance, to: Instance)
	for _, child in from:GetChildren() do
		child.Parent = to
	end
end

function ArenaMapService.bindBalls(arena: ArenaService.Arena)
	BallService.startGroundSpawns(arena.ballSpawns)
	BallService.configureRecovery(arena.ballSpawns, arena.origin.Position.Y + Combat.Dodgeball.RecoveryBelowOffset)
end

function ArenaMapService.currentMapId(): string
	return currentId
end

-- Maps the ballot may offer: the live map plus every enabled staged map that
-- passes the arena contract. Empty when no map vote applies (Splashdown venue,
-- fixed-mode session) or fewer than two maps are usable.
function ArenaMapService.availableMaps(): { string }
	if VenueService.venue() ~= "Arena" or ArenaSessionService.fixedModeId() ~= nil then
		return {}
	end
	local result = {}
	for _, mapId in ArenaMaps.Order do
		if mapId == currentId then
			table.insert(result, mapId)
		else
			local staged = stagedFolder(mapId)
			if staged and auditFailures[mapId] == nil and ArenaService.validate(staged) then
				table.insert(result, mapId)
			end
		end
	end
	if #result < 2 then
		return {}
	end
	return result
end

local function reroutePlayers()
	local origin = ArenaService.get().origin.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if character and root then
			task.spawn(pcall, player.RequestStreamAroundAsync, player, origin, STREAM_TIMEOUT_SECONDS)
			local ok, err = pcall(ArenaService.routeSpawn, character, player, nil, "Cleanup")
			if not ok then
				warn(`[ArenaMapService] could not re-route {player.Name}: {err}`)
			end
		end
	end
end

local function parkTemplateName(mapId: string): string
	local definition = ArenaMaps.Maps[mapId]
	return if definition then definition.Template else mapId
end

-- Moves `staged` (a Folder holding the arena contract) into the live root and
-- parks the current interior in its own template folder. Everything is vetted
-- before anything moves; a failure after the move reverts. Never yields before
-- the swap completes.
function ArenaMapService.swapTo(mapId: string, staged: Folder): (boolean, string?)
	local valid, invalid = ArenaService.validate(staged)
	if not valid then
		return false, invalid
	end
	local stagedScriptables = staged:FindFirstChild("Scriptables") :: Folder
	local tagged, tagReason = ScriptableRoots.tag(stagedScriptables)
	if not tagged then
		ScriptableRoots.untag(stagedScriptables)
		return false, tagReason
	end

	local parkOwner = mapsFolder(false)
	local existingPark = if parkOwner then parkOwner:FindFirstChild(parkTemplateName(currentId)) else nil
	if existingPark and #existingPark:GetChildren() > 0 then
		ScriptableRoots.untag(stagedScriptables)
		return false, "park_not_empty"
	end

	local previous = ArenaService.get()
	local root = previous.root
	local previousScriptables = previous.scriptables
	local parkName = parkTemplateName(currentId)
	local maps = mapsFolder(true) :: Folder
	local park = maps:FindFirstChild(parkName)
	if park == nil or not park:IsA("Folder") then
		local created = Instance.new("Folder")
		created.Name = parkName
		created.Parent = maps
		park = created
	end

	ScriptableRoots.untag(previousScriptables)
	BallService.stopGroundSpawns()
	BallService.clearRecovery()
	BallService.clearAll()

	moveChildren(root, park)
	moveChildren(staged, root)

	local refreshed, refreshReason = ArenaService.refresh()
	if not refreshed then
		moveChildren(root, staged)
		moveChildren(park, root)
		ScriptableRoots.untag(stagedScriptables)
		ScriptableRoots.tag(previousScriptables)
		local restored, restoreReason = ArenaService.refresh()
		if not restored then
			warn(`[ArenaMapService] could not restore previous map after failed swap: {restoreReason}`)
		end
		ArenaMapService.bindBalls(ArenaService.get())
		return false, refreshReason
	end

	ArenaMapService.bindBalls(ArenaService.get())
	currentId = mapId
	root:SetAttribute(MAP_ID_ATTRIBUTE, mapId)
	reroutePlayers()
	return true, nil
end

function ArenaMapService.activate(mapId: string): (boolean, string?)
	if mapId == currentId then
		return true, nil
	end
	if ArenaMaps.Maps[mapId] == nil or not ArenaMaps.Maps[mapId].Enabled then
		return false, "unknown_map"
	end
	if VenueService.venue() ~= "Arena" then
		return false, "not_arena"
	end
	local phase = MatchService.phase()
	if phase == "Starting" or phase == "Active" or phase == "Results" then
		return false, "match_active"
	end
	local staged = stagedFolder(mapId)
	if staged == nil then
		return false, "template_missing"
	end
	return ArenaMapService.swapTo(mapId, staged)
end

-- After VenueService.start. Audits each staged map once so a broken template is
-- reported at boot instead of silently never appearing on the ballot. The ball
-- supply is bound by the boot sequence; rebinding here would undo the stand-down
-- a Splashdown venue just performed.
function ArenaMapService.start()
	if started then
		return
	end
	started = true
	ArenaService.get().root:SetAttribute(MAP_ID_ATTRIBUTE, currentId)
	for _, mapId in ArenaMaps.Order do
		if mapId ~= currentId then
			local staged = stagedFolder(mapId)
			local ok, reason
			if staged == nil then
				ok, reason = false, `no ServerStorage.{MAPS_FOLDER_NAME}.{ArenaMaps.Maps[mapId].Template}`
			else
				ok, reason = ArenaService.validate(staged)
				if ok then
					-- Same check swapTo applies; tagging outside Workspace is inert.
					local scriptables = staged:FindFirstChild("Scriptables") :: Folder
					ok, reason = ScriptableRoots.tag(scriptables)
					ScriptableRoots.untag(scriptables)
					if not ok then
						auditFailures[mapId] = reason or "audit failed"
					end
				end
			end
			if not ok then
				warn(`[ArenaMapService] {mapId} unavailable: {reason}`)
			end
		end
	end
end

return ArenaMapService
