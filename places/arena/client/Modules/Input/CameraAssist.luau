--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))
local AimDirector = require(script.Parent.AimDirector)
local AssistConfig = require(script.Parent.AssistConfig)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local UserInputService = game:GetService("UserInputService")

-- Camera adhesion and aim friction, applied on top of whatever camera the
-- player is already using.
--
-- This deliberately does not fork PlayerModule. Roblox's default camera derives
-- each frame's rotation from the camera's *current* look vector plus that
-- frame's rotate input, so a rotation written after it has run persists into the
-- next frame instead of being discarded. That makes a post-camera pass the
-- cheapest correct place to do this: no vendored copy of PlayerModule to keep in
-- sync, and every camera mode the player can pick keeps working.
--
-- Adhesion pulls the camera along with a target's angular drift so a strafing
-- enemy does not slide out from under the reticle. Friction damps the player's
-- own rotation while the reticle is over a target, so fine adjustment near an
-- enemy is easier than sweeping past them. Both scale by target confidence and
-- by the player's per-player assist strengths, and both are inert at strength 0
-- and on devices whose DeviceScale zeroes them -- which is how mouse and
-- keyboard stay untouched.

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

-- Removes a fraction of the rotation the player applied this frame. Measured
-- against the previous frame's camera rather than against raw touch deltas, so
-- it damps by what actually happened rather than by what was requested.
local function applyFriction(camera: Camera, previous: CFrame, reduction: number)
	local delta = previous:ToObjectSpace(camera.CFrame.Rotation)
	local axis, angle = delta:ToAxisAngle()
	if angle <= 1e-5 or axis.Magnitude <= 1e-5 then
		return
	end
	camera.CFrame = camera.CFrame * CFrame.fromAxisAngle(axis, -angle * reduction)
end

-- Rotates the camera to follow how far the target moved across it since last
-- frame, capped so the pull can never outrun the player's own input.
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
	-- Friction only means anything while the player is turning the camera; off a
	-- drag there is nothing to damp and applying it would fight adhesion.
	if friction > 0 and previousRotation ~= nil and Combat.isCameraTouchActive() then
		applyFriction(camera, previousRotation, friction * MobileInput.Assist.FrictionMaxReduction)
	end

	local adhesion = AssistConfig.strength("Adhesion", device) * confidence
	if adhesion > 0 and previousDirection ~= nil and dt > 0 then
		applyAdhesion(camera, previousDirection, direction, adhesion, dt)
	end

	-- Adhesion moved the camera, so the baseline friction measures against next
	-- frame must be the pose the player is actually looking from now.
	lastRotation = camera.CFrame.Rotation

	-- The shoulder offset used to be applied here as a post-hoc lateral shove of
	-- the camera CFrame. It is now owned by PlayerModule.Combat.CombatCamera,
	-- which sets it through the camera controller's own mouse-lock offset. Two
	-- systems each nudging the camera sideways produced a doubled, drifting
	-- offset that neither one could account for.
end

function CameraAssist.start()
	if started then
		return
	end
	started = true

	-- Runs after the default camera has written its CFrame for this frame.
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraAssist
