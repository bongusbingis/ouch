-- Description: Flies the camera over the standing course while a Splashdown round is being introduced, orbiting the bowl from the intro framing, and hands the camera back to the player for the countdown.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local arenaOrigin = require(script.Parent.ArenaOrigin)

local Splashdown = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local SplashdownClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("SplashdownClient"))
local PresentationCamera = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Services")
		:WaitForChild("PresentationCamera")
)

local SplashdownCamera = {}

local config = Splashdown.Intro

local started = false
local active = false
local angle = 0
local generation = 0
local origin: Vector3? = nil
local cameraLease: PresentationCamera.Token? = nil
local disconnect: (() -> ())? = nil

local function frame(camera: Camera, deltaTime: number)
	local center = origin
	if center == nil then
		return
	end
	angle += math.rad(config.RotationSpeedDeg) * deltaTime
	local offset = Vector3.new(math.cos(angle) * config.Distance, config.Height, math.sin(angle) * config.Distance)
	camera.CFrame = CFrame.lookAt(center + offset, center)
end

local function activate()
	if active then
		return
	end
	active = true
	angle = math.pi / 2
	if cameraLease == nil then
		cameraLease = PresentationCamera.acquire("RaceIntro", PresentationCamera.Priority.Vote, frame)
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
end

function SplashdownCamera.start()
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
		disconnect = SplashdownClient.subscribe(function(snapshot)
			if snapshot.phase == "Intro" then
				activate()
			else
				deactivate()
			end
		end)
	end)
end

function SplashdownCamera.destroy()
	generation += 1
	deactivate()
	if disconnect then
		disconnect()
		disconnect = nil
	end
	origin = nil
	started = false
end

return SplashdownCamera
