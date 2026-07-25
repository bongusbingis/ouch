--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CameraShaker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("camera-shaker"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))

local DamageFeedback = {}

local localPlayer = Players.LocalPlayer
local seen = EventDedup.new(4096)
local cameraShake: any = nil
local impulseFrame: Frame? = nil
local impulseGradient: UIGradient? = nil
local activeTween: Tween? = nil
local confirmTween: Tween? = nil
local confirmLabel: TextLabel? = nil
local confirmGeneration = 0

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

	local matchFlow = hud:WaitForChild("MatchFlow")
	local label = matchFlow:WaitForChild("ActionFeedback")
	assert(label:IsA("TextLabel"), "[DamageFeedback] Hud.MatchFlow.ActionFeedback must be a TextLabel")
	confirmLabel = label
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

local function confirm(text: string, color: Color3)
	local label = confirmLabel
	if label == nil then
		return
	end
	if confirmTween then
		confirmTween:Cancel()
		confirmTween = nil
	end
	confirmGeneration += 1
	local generation = confirmGeneration
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.Visible = true
	task.delay(Combat.DamageFeedback.ConfirmHoldTime, function()
		if generation ~= confirmGeneration or label.Parent == nil then
			return
		end
		local tween = TweenService:Create(
			label,
			TweenInfo.new(Combat.DamageFeedback.ConfirmFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)
		confirmTween = tween
		tween.Completed:Once(function()
			if generation == confirmGeneration then
				confirmTween = nil
				label.Visible = false
			end
		end)
		tween:Play()
	end)
end

function DamageFeedback.start()
	setupCameraShake()
	setupImpulseGui()
end

function DamageFeedback.onEvent(event: any)
	local localId = PlayerIds.toId(localPlayer)
	local relevant = event.targetId == localId or event.sourceId == localId or event.playerId == localId
	if not relevant or not seen.markSeen(event) then
		return
	end

	if event.kind == "Elim" then
		if event.targetId == localId then
			shake()
			flash()
		elseif event.sourceId == localId then
			confirm("SPLAT!", Color3.fromRGB(255, 101, 139))
		end
	elseif event.kind == "BallCaught" and (event.playerId == localId or event.sourceId == localId) then
		confirm("CAUGHT!", Color3.fromRGB(74, 239, 190))
	elseif event.kind == "CatchStarted" then
		confirm("CATCH!", Color3.fromRGB(255, 232, 123))
	elseif event.kind == "CatchMissed" then
		confirm("MISSED", Color3.fromRGB(255, 159, 87))
	end
end

return DamageFeedback
