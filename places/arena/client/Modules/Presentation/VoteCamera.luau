-- Description: Moves the camera to the authored vote framing while the game-mode ballot is open and returns it to the player on close.

--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local arenaOrigin = require(script.Parent.ArenaOrigin)

local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ArenaMaps = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("ArenaMaps"))
local ModeVoteClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ModeVoteClient"))
local PostMatchClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("PostMatchClient"))

local PresentationCamera = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Services")
		:WaitForChild("PresentationCamera")
)

local VoteCamera = {}

local config = UI.VoteCamera

local started = false
local active = false
local angle = 0
local generation = 0
local origin: Vector3? = nil
local distance: number = config.Distance
local height: number = config.Height
local blur: BlurEffect? = nil
local cameraLease: PresentationCamera.Token? = nil
local voteDisconnect: (() -> ())? = nil
local postMatchDisconnect: (() -> ())? = nil

local function frame(camera: Camera, deltaTime: number)
	local part = origin
	if part == nil then
		return
	end
	angle += math.rad(config.RotationSpeedDeg) * deltaTime
	local center = part
	local offset = Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
	camera.CFrame = CFrame.lookAt(center + offset, center)
end

-- The live map can change between ballots, so the orbit re-reads the origin and the
-- per-map framing each time it opens. A missing attribute keeps the last value.
local function refreshFraming()
	local arena = Workspace:FindFirstChild("Assets")
	arena = if arena then arena:FindFirstChild("Arena") else nil
	if arena == nil then
		return
	end
	local position = arena:GetAttribute("MapOriginPosition")
	if typeof(position) == "Vector3" then
		origin = position
	end
	local mapId = arena:GetAttribute("ArenaMapId")
	local definition = if typeof(mapId) == "string" then ArenaMaps.Maps[mapId] else nil
	local override = if definition then definition.VoteCamera else nil
	distance = if override then override.Distance else config.Distance
	height = if override then override.Height else config.Height
end

local function activate()
	if active then
		return
	end
	active = true
	refreshFraming()

	if blur == nil then
		local effect = Instance.new("BlurEffect")
		effect.Size = config.BlurSize
		effect.Parent = Lighting
		blur = effect
	end
	if cameraLease == nil then
		cameraLease = PresentationCamera.acquire("Vote", PresentationCamera.Priority.Vote, frame)
	end
end

local function deactivate()
	if not active then
		return
	end
	active = false

	if cameraLease then
		PresentationCamera.release(cameraLease)
		cameraLease = nil
	end
	if blur then
		blur:Destroy()
		blur = nil
	end
end

function VoteCamera.start()
	if started then
		return
	end
	started = true
	generation += 1
	local currentGeneration = generation

	task.spawn(function()
		local position = arenaOrigin()
		if generation ~= currentGeneration then
			return
		end
		origin = position

		-- A player leaving for the lobby keeps the results stage; the ballot never takes their camera.
		local function evaluate()
			local snapshot = ModeVoteClient.getSnapshot()
			if snapshot.admitted and snapshot.open and not PostMatchClient.getSnapshot().departing then
				activate()
			else
				deactivate()
			end
		end
		voteDisconnect = ModeVoteClient.subscribe(evaluate)
		postMatchDisconnect = PostMatchClient.subscribe(evaluate)
		evaluate()
	end)
end

function VoteCamera.destroy()
	generation += 1
	deactivate()
	if voteDisconnect then
		voteDisconnect()
		voteDisconnect = nil
	end
	if postMatchDisconnect then
		postMatchDisconnect()
		postMatchDisconnect = nil
	end
	origin = nil
	started = false
end

return VoteCamera
