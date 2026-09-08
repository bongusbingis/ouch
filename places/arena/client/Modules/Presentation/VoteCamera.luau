-- Description: Moves the camera to the authored vote framing while the game-mode ballot is open and returns it to the player on close.

--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local arenaOrigin = require(script.Parent.ArenaOrigin)

local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ModeVoteClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ModeVoteClient"))

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
local blur: BlurEffect? = nil
local cameraLease: PresentationCamera.Token? = nil
local voteDisconnect: (() -> ())? = nil

local function frame(camera: Camera, deltaTime: number)
	local part = origin
	if part == nil then
		return
	end
	angle += math.rad(config.RotationSpeedDeg) * deltaTime
	local center = part
	local offset = Vector3.new(math.cos(angle) * config.Distance, config.Height, math.sin(angle) * config.Distance)
	camera.CFrame = CFrame.lookAt(center + offset, center)
end

local function activate()
	if active then
		return
	end
	active = true

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

		voteDisconnect = ModeVoteClient.subscribe(function(snapshot)
			if snapshot.admitted and snapshot.open then
				activate()
			else
				deactivate()
			end
		end)

		local snapshot = ModeVoteClient.getSnapshot()
		if snapshot.admitted and snapshot.open then
			activate()
		end
	end)
end

function VoteCamera.destroy()
	generation += 1
	deactivate()
	if voteDisconnect then
		voteDisconnect()
		voteDisconnect = nil
	end
	origin = nil
	started = false
end

return VoteCamera
