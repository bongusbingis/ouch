-- Description: Shakes the camera and plays the local hit reaction when the local player is struck, deduplicating sim events that can be broadcast more than once.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CameraShaker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("camera-shaker"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local SettingsStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Settings"):WaitForChild("SettingsStore")
)

local DamageFeedback = {}

local localPlayer = Players.LocalPlayer
local seen = EventDedup.new(32)
local cameraShake: any = nil

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
	if cameraShake == nil then
		cameraShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCFrame: CFrame)
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= shakeCFrame
			end
		end)
		cameraShake:Start()
	end
end

function DamageFeedback.destroy()
	if cameraShake then
		cameraShake:Stop()
		cameraShake = nil
	end
	seen.clear()
end

function DamageFeedback.onEvent(event: any)
	if event.kind == "Elim" and event.targetId == PlayerIds.toId(localPlayer) and seen.markSeen(event) then
		if SettingsStore.get("CameraShake") ~= false then
			shake()
		end
	end
end

return DamageFeedback
