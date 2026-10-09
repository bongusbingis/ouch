-- Description: Cuts between three fixed, authored course compositions on the server's intro timeline, then restores the player camera for countdown.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local arenaOrigin = require(script.Parent.ArenaOrigin)

local IntroModel = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Models")
		:WaitForChild("SplashdownIntroModel")
)
local SplashdownClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("SplashdownClient"))
local PresentationCamera = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Services")
		:WaitForChild("PresentationCamera")
)

local SplashdownCamera = {}

local started = false
local generation = 0
local origin: CFrame? = nil
local intro: SplashdownClient.Snapshot? = nil
local cameraLease: PresentationCamera.Token? = nil
local touchControlsBeforeIntro: boolean? = nil
local disconnect: (() -> ())? = nil

local function point(value: { number }): Vector3
	return Vector3.new(value[1], value[2], value[3])
end

local function deactivate()
	intro = nil
	if cameraLease then
		PresentationCamera.release(cameraLease)
		cameraLease = nil
	end
	if touchControlsBeforeIntro ~= nil then
		GuiService.TouchControlsEnabled = touchControlsBeforeIntro
		touchControlsBeforeIntro = nil
	end
end

local function frame(camera: Camera, _deltaTime: number)
	local snapshot, courseOrigin = intro, origin
	if not snapshot or not courseOrigin then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now >= snapshot.phaseEndsAt then
		deactivate()
		return
	end
	local shot = IntroModel.sample(snapshot.courseId, snapshot.phaseEndsAt, now).shot
	local eye = courseOrigin:PointToWorldSpace(point(shot.Eye))
	local target = courseOrigin:PointToWorldSpace(point(shot.Look))
	camera.CFrame = CFrame.lookAt(eye, target, courseOrigin.UpVector)
	camera.Focus = CFrame.new(target)
	camera.FieldOfView =
		IntroModel.fieldOfView(shot.FieldOfView, camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y))
end

local function onSnapshot(snapshot: SplashdownClient.Snapshot)
	if snapshot.phase ~= "Intro" or snapshot.phaseEndsAt <= Workspace:GetServerTimeNow() then
		deactivate()
		return
	end
	local newSequence = intro == nil or intro.courseId ~= snapshot.courseId or intro.phaseEndsAt ~= snapshot.phaseEndsAt
	intro = snapshot
	if cameraLease == nil then
		touchControlsBeforeIntro = GuiService.TouchControlsEnabled
		GuiService.TouchControlsEnabled = false
		cameraLease = PresentationCamera.acquire("RaceIntro", PresentationCamera.Priority.Vote, frame)
	end
	if newSequence and Workspace.StreamingEnabled and origin then
		local courseOrigin = origin
		local currentGeneration = generation
		task.spawn(function()
			for _, shot in IntroModel.course(snapshot.courseId).Shots do
				if
					generation ~= currentGeneration
					or intro == nil
					or intro.courseId ~= snapshot.courseId
					or intro.phaseEndsAt ~= snapshot.phaseEndsAt
				then
					return
				end
				-- Streaming is best effort; it never delays the authoritative start.
				pcall(function()
					Players.LocalPlayer:RequestStreamAroundAsync(courseOrigin:PointToWorldSpace(point(shot.Look)), 1)
				end)
			end
		end)
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
		local projected = Workspace.Assets.Arena:GetAttribute("MapOriginCFrame")
		origin = if typeof(projected) == "CFrame" then projected else CFrame.new(position)
		disconnect = SplashdownClient.subscribe(onSnapshot)
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
