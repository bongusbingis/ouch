-- Name: DeathEffects.luau
-- Author: Jack C.
-- Description: Plays the local elimination sequence: desaturates the screen, pulls the camera into a spectator zoom, and holds it until the respawn timer configured by the active mode elapses.
-- Created: 2026-07-13

--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local SharedGame = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ModeRegistry = require(SharedGame:WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local PlayerIds = require(SharedGame:WaitForChild("Adapters"):WaitForChild("PlayerIds"))

local DeathEffects = {}

local localPlayer = Players.LocalPlayer

local colorCorrection: ColorCorrectionEffect? = nil
local matchState: Instance? = nil
local zoomConnection: RBXScriptConnection? = nil
local activeTween: Tween? = nil
local characterConnection: RBXScriptConnection? = nil
local sequenceToken = 0

local lastKillerId: string? = nil

local function respawnSeconds(): number
	local deadline = localPlayer:GetAttribute("MatchRespawnAt")
	if typeof(deadline) == "number" then
		return math.max(deadline - Workspace:GetServerTimeNow(), 0.05)
	end
	local modeId = if matchState then (matchState:GetAttribute("modeId") :: string?) or "" else ""
	local mode = ModeRegistry.get(modeId) or ModeRegistry.default()
	return math.max(mode.resolveRules().RespawnSeconds, 0.05)
end

local function ensureColorCorrection(): ColorCorrectionEffect
	local effect = colorCorrection
	if effect == nil then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "DeathColorCorrection"
		effect.Parent = Lighting
		colorCorrection = effect
	end
	return effect :: ColorCorrectionEffect
end

local function tweenSaturation(effect: ColorCorrectionEffect, saturation: number, duration: number): Tween
	if activeTween then
		activeTween:Cancel()
	end
	local tween = TweenService:Create(
		effect,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Saturation = saturation }
	)
	activeTween = tween
	tween:Play()
	return tween
end

local function bodyPosition(character: Model): Vector3?
	local body = character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
	if body and body:IsA("BasePart") then
		return body.Position
	end
	return nil
end

local function stopZoom()
	if zoomConnection then
		zoomConnection:Disconnect()
		zoomConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function startZoom(character: Model)
	stopZoom()
	local camera = Workspace.CurrentCamera
	local startBody = bodyPosition(character)
	if camera == nil or startBody == nil then
		return
	end

	local cfg = Combat.Elimination
	local startPosition = camera.CFrame.Position
	local flatDirection = startPosition - startBody
	local direction = if vector.magnitude(flatDirection) > 1e-3
		then vector.normalize(flatDirection + Vector3.new(0, vector.magnitude(flatDirection) * cfg.CameraUpBias, 0))
		else Vector3.new(0, cfg.CameraUpBias, 1).Unit
	local startDistance = math.max(vector.magnitude(startPosition - startBody), 6)
	local duration = respawnSeconds()

	camera.CameraType = Enum.CameraType.Scriptable
	local elapsed = 0
	zoomConnection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed = math.min(elapsed + dt, duration)
		local alpha = TweenService:GetValue(elapsed / duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local body = bodyPosition(character) or startBody
		local distance = startDistance + cfg.CameraZoomOutDistance * alpha
		camera.CFrame = CFrame.lookAt(body + direction * distance, body)
	end)
end

local endSequence: () -> ()

local function beginSequence(character: Model)
	sequenceToken += 1
	tweenSaturation(ensureColorCorrection(), -1, Combat.Elimination.DesaturateTime)
	startZoom(character)
	local token = sequenceToken
	task.delay(respawnSeconds() + Combat.Elimination.ResaturateTime, function()
		if sequenceToken == token then
			endSequence()
		end
	end)
end

endSequence = function()
	sequenceToken += 1
	stopZoom()
	local effect = colorCorrection
	if effect then
		local tween = tweenSaturation(effect, 0, Combat.Elimination.ResaturateTime)
		tween.Completed:Once(function()
			if activeTween == tween and colorCorrection == effect then
				activeTween = nil
				colorCorrection = nil
				effect:Destroy()
			end
		end)
	end
	lastKillerId = nil
end

function DeathEffects.notifyElim(event: any)
	if event.kind ~= "Elim" or event.targetId ~= PlayerIds.toId(localPlayer) then
		return
	end

	local character = localPlayer.Character
	if character == nil then
		return
	end

	lastKillerId = event.sourceId
	beginSequence(character)
end

local function bindCharacter(character: Model)
	endSequence()
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	characterConnection = character:GetAttributeChangedSignal("CombatAlive"):Connect(function()
		if character:GetAttribute("CombatAlive") == false then
			beginSequence(character)
		else
			endSequence()
		end
	end)
	if character:GetAttribute("CombatAlive") == false then
		beginSequence(character)
	end
end

function DeathEffects.start()
	task.spawn(function()
		matchState = ReplicatedStorage:WaitForChild("MatchState")
	end)

	localPlayer.CharacterAdded:Connect(bindCharacter)
	local character = localPlayer.Character
	if character then
		bindCharacter(character)
	end
end

return DeathEffects
