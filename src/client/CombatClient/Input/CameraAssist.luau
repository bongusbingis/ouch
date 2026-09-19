-- Description: Applies rotational friction and adhesion to the camera when the player is aiming near a valid target, making gamepad and touch aiming stick without taking control away.

--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MobileInput =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("MobileInput"))
local AimDirector = require(script.Parent.AimDirector)
local AssistConfig = require(script.Parent.AssistConfig)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input"))
local UserInputService = game:GetService("UserInputService")

local CameraAssist = {}

local RENDER_NAME = "ArenaCameraAssist"

local started = false
local lastRotation: CFrame? = nil
local lastTargetDirection: Vector3? = nil

local function targetRoot(target: Model?): BasePart?
	if target == nil then
		return nil
	end
	local root = target:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function applyFriction(camera: Camera, previous: CFrame, reduction: number)
	local delta = previous:ToObjectSpace(camera.CFrame.Rotation)
	local axis, angle = delta:ToAxisAngle()
	if angle <= 1e-5 or axis.Magnitude <= 1e-5 then
		return
	end
	camera.CFrame = camera.CFrame * CFrame.fromAxisAngle(axis, -angle * reduction)
end

local function applyAdhesion(
	camera: Camera,
	previousDirection: Vector3,
	direction: Vector3,
	strength: number,
	dt: number
)
	local axis = previousDirection:Cross(direction)
	if axis.Magnitude <= 1e-6 then
		return
	end
	local angle = math.acos(math.clamp(previousDirection:Dot(direction), -1, 1))
	if angle <= 1e-6 then
		return
	end

	local maxAngle = math.rad(MobileInput.Assist.AdhesionMaxDegPerSecond) * dt
	local applied = math.min(angle * strength, maxAngle)
	if applied <= 1e-6 then
		return
	end

	local position = camera.CFrame.Position
	camera.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(axis.Unit, applied) * (camera.CFrame - position)
end

local function update(dt: number)
	if not Combat.isActive() then
		lastRotation = nil
		lastTargetDirection = nil
		return
	end
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if camera == nil or character == nil then
		lastRotation = nil
		lastTargetDirection = nil
		return
	end

	local previousRotation = lastRotation
	local previousDirection = lastTargetDirection
	lastRotation = camera.CFrame.Rotation

	local target = AimDirector.currentTarget()
	local root = targetRoot(target)
	if root == nil then
		lastTargetDirection = nil
		return
	end

	local offset = root.Position - camera.CFrame.Position
	if offset.Magnitude <= 1e-4 then
		lastTargetDirection = nil
		return
	end
	local direction = offset.Unit
	lastTargetDirection = direction

	local confidence = AimDirector.currentConfidence()
	if confidence <= 0 then
		return
	end
	local device = AimDirector.deviceClass()

	local friction = AssistConfig.strength("Friction", device) * confidence
	if friction > 0 and previousRotation ~= nil and Combat.isCameraTouchActive() then
		applyFriction(camera, previousRotation, friction * MobileInput.Assist.FrictionMaxReduction)
	end

	local adhesion = AssistConfig.strength("Adhesion", device) * confidence
	if adhesion > 0 and previousDirection ~= nil and dt > 0 then
		applyAdhesion(camera, previousDirection, direction, adhesion, dt)
	end

	lastRotation = camera.CFrame.Rotation
end

function CameraAssist.start()
	if started then
		return
	end
	started = true

	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, update)
end

function CameraAssist.stop()
	if not started then
		return
	end
	started = false
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
	lastRotation = nil
	lastTargetDirection = nil
end

return CameraAssist
