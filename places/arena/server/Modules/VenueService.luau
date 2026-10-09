-- Description: Decides once per server which venue the stadium runs -- the authored arena interior, or a Splashdown course standing in the bowl -- from the session the first arrival established, parks the arena interior in ServerStorage for a Splashdown server and never swaps back.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local ScriptableRoots = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ScriptableRoots")
)

local ArenaService = require(script.Parent.ArenaService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local BallService = require(script.Parent.BallService)

local VenueService = {}

export type Venue = "Arena" | "Splashdown"

local PARK_NAME = "ArenaInterior"
local INTERIOR = { "Level_1", "Level_2", "Level_3" }
local MAP_CHILDREN = { "Boundary" }
local SIBLINGS = { "Scriptables", "PlayerSpawns", "TeamSpawns" }

local venue: Venue = "Arena"
local listeners: { (Venue) -> () } = {}
local started = false

local function venueFor(fixedModeId: string?): Venue
	local definition = if fixedModeId then GameModes.Modes[fixedModeId] else nil
	return if definition and definition.Spawn == "Course" then "Splashdown" else "Arena"
end

local function dispatch()
	for _, listener in table.clone(listeners) do
		local ok, err = pcall(listener, venue)
		if not ok then
			warn(`[VenueService] venue listener failed: {err}`)
		end
	end
end

-- The arena's kits and ball supply are keyed off the interior, so they stand
-- down before it leaves the Workspace; the map shell, lighting and MapOrigin stay.
local function swapToSplashdown()
	local arena = ArenaService.get()
	ScriptableRoots.untag(arena.scriptables)
	BallService.stopGroundSpawns()
	BallService.clearRecovery()
	BallService.clearAll()

	local park = Instance.new("Folder")
	park.Name = PARK_NAME
	park.Parent = ServerStorage
	local model = arena.map:WaitForChild("Model")
	assert(model:IsA("Model"), "[VenueService] Workspace.Assets.Arena.Map.Model must be a Model")
	for _, name in INTERIOR do
		local level = model:FindFirstChild(name)
		if level then
			level.Parent = park
		end
	end
	-- The arena's boundary ring is tighter than the courses; each course
	-- template carries its own wider ring.
	for _, name in MAP_CHILDREN do
		local child = arena.map:FindFirstChild(name)
		if child then
			child.Parent = park
		end
	end
	for _, name in SIBLINGS do
		local sibling = arena.root:FindFirstChild(name)
		if sibling then
			sibling.Parent = park
		end
	end
	arena.root:SetAttribute("Venue", "Splashdown")
	venue = "Splashdown"
	dispatch()
end

function VenueService.start()
	if started then
		return
	end
	started = true
	ArenaService.start()
	ArenaSessionService.onSessionEstablished(function(_queueId: string, fixedModeId: string?)
		if venue == "Arena" and venueFor(fixedModeId) == "Splashdown" then
			swapToSplashdown()
		end
	end)
end

function VenueService.venue(): Venue
	return venue
end

function VenueService.parkedInterior(): Folder?
	local park = ServerStorage:FindFirstChild(PARK_NAME)
	return if park and park:IsA("Folder") then park else nil
end

-- Fires when the venue changes; a listener added after the swap hears it at once.
function VenueService.onChanged(listener: (Venue) -> ()): () -> ()
	table.insert(listeners, listener)
	if venue ~= "Arena" then
		listener(venue)
	end
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

return VenueService
