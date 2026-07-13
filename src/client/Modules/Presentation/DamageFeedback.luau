--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CameraShaker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("camera-shaker"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

local DamageFeedback = {}

local localPlayer = Players.LocalPlayer
local seenEvents: { [string]: boolean } = {}
local cameraShake: any = nil
local impulseFrame: Frame? = nil
local impulseGradient: UIGradient? = nil
local activeTween: Tween? = nil

local EDGE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.34, 1),
	NumberSequenceKeypoint.new(0.66, 1),
	NumberSequenceKeypoint.new(1, 0),
})

local function setupCameraShake()
	cameraShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCFrame: CFrame)
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CFrame *= shakeCFrame
		end
	end)
	cameraShake:Start()
end

local function setupImpulseGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("Hud")
	local frame = hud:WaitForChild("DamageImpulse")
	assert(frame:IsA("Frame"), "[DamageFeedback] ScreenGui.Hud.DamageImpulse must be a Frame")

	local gradient = frame:WaitForChild("UIGradient")
	assert(gradient:IsA("UIGradient"), "[DamageFeedback] DamageImpulse.UIGradient must be a UIGradient")

	frame.Visible = false
	frame.BackgroundTransparency = 1
	gradient.Transparency = EDGE_TRANSPARENCY
	gradient.Rotation = 0

	impulseFrame = frame
	impulseGradient = gradient
end

local function flash()
	local frame = impulseFrame
	local gradient = impulseGradient
	if frame == nil or gradient == nil then
		return
	end

	if activeTween then
		activeTween:Cancel()
	end

	local cfg = Combat.DamageFeedback
	frame.Visible = true
	frame.BackgroundTransparency = 1
	gradient.Transparency = EDGE_TRANSPARENCY

	local inTween = TweenService:Create(
		frame,
		TweenInfo.new(cfg.FlashInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = cfg.FlashPeakTransparency }
	)
	local outTween = TweenService:Create(
		frame,
		TweenInfo.new(cfg.FlashOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)

	activeTween = inTween
	inTween.Completed:Once(function()
		activeTween = outTween
		outTween:Play()
	end)
	outTween.Completed:Once(function()
		if activeTween == outTween then
			activeTween = nil
			frame.Visible = false
		end
	end)
	inTween:Play()
end

local function shake()
	local cfg = Combat.DamageFeedback
	local positionInfluence = cfg.ShakePositionInfluence
	local rotationInfluence = cfg.ShakeRotationInfluence
	cameraShake:ShakeOnce(
		cfg.ShakeMagnitude,
		cfg.ShakeRoughness,
		cfg.ShakeFadeIn,
		cfg.ShakeFadeOut,
		Vector3.new(positionInfluence.x, positionInfluence.y, positionInfluence.z),
		Vector3.new(rotationInfluence.x, rotationInfluence.y, rotationInfluence.z)
	)
end

function DamageFeedback.start()
	setupCameraShake()
	setupImpulseGui()
end

function DamageFeedback.onEvent(event: any)
	if event.kind ~= "Elim" or event.targetId ~= tostring(localPlayer.UserId) then
		return
	end

	local key = `{event.tick}:{event.kind}:{event.sourceId or ""}:{event.targetId or ""}:{event.projectileId or ""}`
	if seenEvents[key] then
		return
	end
	seenEvents[key] = true

	shake()
	flash()
end

return DamageFeedback
