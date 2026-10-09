-- Description: Plays the shared ConfettiImpact cosmetic effect for onboarding knockouts and completion, so the confetti/flash visual lives in one place rather than being duplicated here.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OnboardingClient = require(script.Parent:WaitForChild("OnboardingClient"))
local OnboardingTargets = require(script.Parent:WaitForChild("OnboardingTargets"))
local GameAudio = require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("GameAudio"))
local CosmeticEffectFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticEffectFactory")
)

local OnboardingImpactVFX = {}

local CELEBRATION_ECHO_SECONDS = 0.16

local started = false
local unsubscribe: (() -> ())? = nil
local unsubscribeCue: (() -> ())? = nil
local celebrated = false
local celebrationRevision = 0

local function play(position: Vector3, scale: number)
	CosmeticEffectFactory.play("Impact", "ConfettiImpact", { position = position, scale = scale })
end

local function burst(_target: Model, at: Vector3)
	play(at, 1)
	GameAudio.play("OnboardingDummyLaunch", at)
end

local function onSnapshot(snapshot: any)
	if not snapshot.active or snapshot.cue ~= "Done" then
		celebrated = false
		return
	end
	if celebrated then
		return
	end
	celebrated = true
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local at = root.Position
	play(at, 1.2)
	celebrationRevision += 1
	local revision = celebrationRevision
	task.delay(CELEBRATION_ECHO_SECONDS, function()
		if started and celebrationRevision == revision then
			play(at, 1)
		end
	end)
end

function OnboardingImpactVFX.start()
	if started then
		return
	end
	started = true
	unsubscribe = OnboardingTargets.onLost(burst)
	unsubscribeCue = OnboardingClient.subscribe(onSnapshot)
end

function OnboardingImpactVFX.destroy()
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	if unsubscribeCue then
		unsubscribeCue()
		unsubscribeCue = nil
	end
	celebrated = false
	celebrationRevision += 1
	started = false
end

return OnboardingImpactVFX
