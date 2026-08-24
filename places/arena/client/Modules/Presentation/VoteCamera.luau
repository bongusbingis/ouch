--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))
local ModeVoteClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ModeVoteClient"))

-- Orbits the camera around the arena's authored MapOrigin while the mode vote is
-- open, and blurs the world behind the ballot. Presentation only: it derives
-- entirely from the replicated vote snapshot and owns nothing but the camera
-- mode and the blur it creates.

local VoteCamera = {}

local config = UI.VoteCamera

local started = false
local active = false
local angle = 0
local origin: BasePart? = nil
local blur: BlurEffect? = nil
local renderConnection: RBXScriptConnection? = nil
local voteDisconnect: (() -> ())? = nil

local function frame(deltaTime: number)
	local part = origin
	local camera = Workspace.CurrentCamera
	if part == nil or camera == nil then
		return
	end
	angle += math.rad(config.RotationSpeedDeg) * deltaTime
	local center = part.Position
	local offset = Vector3.new(math.cos(angle) * config.Distance, config.Height, math.sin(angle) * config.Distance)
	camera.CFrame = CFrame.lookAt(center + offset, center)
end

local function activate()
	if active then
		return
	end
	active = true

	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if blur == nil then
		local effect = Instance.new("BlurEffect")
		effect.Size = config.BlurSize
		effect.Parent = Lighting
		blur = effect
	end
	if renderConnection == nil then
		renderConnection = RunService.RenderStepped:Connect(frame)
	end
	frame(0)
end

local function deactivate()
	if not active then
		return
	end
	active = false

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if blur then
		blur:Destroy()
		blur = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildWhichIsA("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
	end
end

function VoteCamera.start()
	if started then
		return
	end
	started = true

	local arena = Workspace:WaitForChild("Assets"):WaitForChild("Arena")
	local part = arena:WaitForChild("MapOrigin")
	assert(part:IsA("BasePart"), "[VoteCamera] Workspace.Assets.Arena.MapOrigin must be a BasePart")
	origin = part

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
end

function VoteCamera.destroy()
	deactivate()
	if voteDisconnect then
		voteDisconnect()
		voteDisconnect = nil
	end
	origin = nil
	started = false
end

return VoteCamera
