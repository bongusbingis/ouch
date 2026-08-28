-- Name: AimDirector.luau
-- Author: Jack C.
-- Description: Owns the local player's aim direction and soft-lock target selection each frame, sampling the camera and nearby characters to produce the aim vector, chosen target, target motion, and a confidence score for the rest of the client.
-- Created: 2026-07-13

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AimAssist"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))
local SharedGame = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local PlayerIds = require(SharedGame:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local CombatSession = require(SharedGame:WaitForChild("Adapters"):WaitForChild("CombatSession"))
local Intercept = require(SharedGame:WaitForChild("Sim"):WaitForChild("Intercept"))

local AimDirector = {}

type Vec = vector

local currentTarget: Model? = nil
local currentAimDir: Vector3 = Vector3.zAxis
local currentConfidence = 0

local presentationParams = RaycastParams.new()
presentationParams.FilterType = Enum.RaycastFilterType.Exclude
presentationParams.RespectCanCollide = true
local presentationExclusions: { Instance } = {}

local trajectoryParams = RaycastParams.new()
trajectoryParams.FilterType = Enum.RaycastFilterType.Exclude
trajectoryParams.RespectCanCollide = true
local trajectoryExclusions: { Instance } = {}

local velocityHistories: { [Model]: { Vec } } = setmetatable({}, { __mode = "k" }) :: any

local function toVec(value: Vector3): Vec
	return vector.create(value.X, value.Y, value.Z)
end

export type Candidate = { id: string, character: Model, player: Player? }
export type CharacterSource = () -> { [string]: Model }

local characterSources: { [string]: CharacterSource } = {}

-- The client mirror of ServerAuthAdapter.registerCharacterSource: non-player
-- sim characters the local player can aim at. Registering here is what keeps
-- reticle and trajectory targeting from special-casing them.
function AimDirector.registerCharacterSource(name: string, source: CharacterSource)
	characterSources[name] = source
end

function AimDirector.unregisterCharacterSource(name: string)
	characterSources[name] = nil
end

-- Exposed so the trajectory preview sweeps against exactly the set the reticle
-- can target, dummies included.
function AimDirector.candidates(): { Candidate }
	local list: { Candidate } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player ~= Players.LocalPlayer and character ~= nil then
			table.insert(list, { id = PlayerIds.toId(player), character = character, player = player })
		end
	end
	for name, source in characterSources do
		local ok, extra = pcall(source)
		if not ok then
			warn(`[AimDirector] character source {name} errored: {extra}`)
			continue
		end
		for id, character in extra :: { [string]: Model } do
			table.insert(list, { id = id, character = character, player = nil })
		end
	end
	return list
end

function AimDirector.deviceClass(): string
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.find(lastInput.Name, "Gamepad", 1, true) == 1 then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Mouse"
end

local function deviceRow(): AimAssist.DeviceRow
	return AimAssist[AimDirector.deviceClass()] or AimAssist.Mouse
end

local function refreshPresentationExclusions(character: Model)
	table.clear(presentationExclusions)
	table.insert(presentationExclusions, character)
	local balls = Workspace:FindFirstChild("Balls")
	if balls ~= nil then
		table.insert(presentationExclusions, balls)
	end
	presentationParams.FilterDescendantsInstances = presentationExclusions
end

local function presentationVisible(camera: Camera, targetRoot: BasePart): boolean
	local offset = targetRoot.Position - camera.CFrame.Position
	local hit = Workspace:Raycast(camera.CFrame.Position, offset, presentationParams)
	return hit == nil or hit.Instance:IsDescendantOf(targetRoot.Parent :: Instance)
end

local function refreshTrajectoryExclusions(list: { Candidate })
	table.clear(trajectoryExclusions)
	local localCharacter = Players.LocalPlayer.Character
	if localCharacter ~= nil then
		table.insert(trajectoryExclusions, localCharacter)
	end
	for _, candidate in list do
		table.insert(trajectoryExclusions, candidate.character)
	end
	local balls = Workspace:FindFirstChild("Balls")
	if balls ~= nil then
		table.insert(trajectoryExclusions, balls)
	end
	trajectoryParams.FilterDescendantsInstances = trajectoryExclusions
end

local function trajectoryVisible(origin: Vector3, targetRoot: BasePart): boolean
	local offset = targetRoot.Position - origin
	local distance = offset.Magnitude
	if distance <= 1e-4 then
		return true
	end
	local hit = Workspace:Spherecast(origin, 0.2, offset, trajectoryParams)
	return hit == nil or hit.Distance >= distance - Combat.CharacterCapsule.Radius
end

local function angleFromLook(camera: Camera, position: Vector3): number
	local offset = position - camera.CFrame.Position
	if offset.Magnitude <= 1e-4 then
		return 0
	end
	return math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
end

local function presentationRoot(character: Model, localTeamId: any): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	if character:GetAttribute("CombatAlive") == false then
		return nil
	end
	if localTeamId ~= nil and character:GetAttribute("TeamId") == localTeamId then
		return nil
	end
	return root
end

local function trajectoryRoot(candidate: Candidate, localTeamId: any): BasePart?
	local player = candidate.player
	if player ~= nil and not CombatSession.isLive(player) then
		return nil
	end
	if candidate.character:GetAttribute("minv") == true then
		return nil
	end
	return presentationRoot(candidate.character, localTeamId)
end

local function sampleVelocity(character: Model, root: BasePart)
	local samples = velocityHistories[character]
	if samples == nil then
		samples = {}
		velocityHistories[character] = samples
	end
	table.insert(samples, toVec(root.AssemblyLinearVelocity))
	if #samples > MobileInput.Assist.VelocitySamples then
		table.remove(samples, 1)
	end
end

local function confidenceFor(angleDeg: number, coneDeg: number): number
	if coneDeg <= 1e-4 then
		return 0
	end
	local fraction = math.clamp(angleDeg / coneDeg, 0, 1)
	local fadeStart = MobileInput.Assist.ConeFadeStartFraction
	if fraction <= fadeStart then
		return 1
	end
	if fadeStart >= 1 then
		return 1
	end
	return 1 - (fraction - fadeStart) / (1 - fadeStart)
end

local function selectPresentationTarget(camera: Camera, character: Model): (Model?, number)
	local row = deviceRow()
	local localTeamId = character:GetAttribute("TeamId")
	local localRoot = character:FindFirstChild("HumanoidRootPart")
	if localRoot == nil or not localRoot:IsA("BasePart") then
		return nil, 0
	end
	refreshPresentationExclusions(character)

	local best: Model? = nil
	local bestScore = math.huge
	local bestConfidence = 0
	for _, candidate in AimDirector.candidates() do
		local targetCharacter = candidate.character
		local root = presentationRoot(targetCharacter, localTeamId)
		if root == nil then
			continue
		end
		sampleVelocity(targetCharacter, root)
		local distance = (root.Position - localRoot.Position).Magnitude
		if distance <= 0 or distance > Combat.Dodgeball.TargetSelectRange then
			continue
		end

		local angle = angleFromLook(camera, root.Position)
		local coneDeg = if targetCharacter == currentTarget then row.StickyConeDeg else row.AcquireConeDeg
		if angle > coneDeg or not presentationVisible(camera, root) then
			continue
		end

		local score = math.rad(angle) + distance * 1e-3 - (if targetCharacter == currentTarget then 0.15 else 0)
		if score < bestScore then
			best = targetCharacter
			bestScore = score
			bestConfidence = confidenceFor(angle, coneDeg)
		end
	end
	return best, bestConfidence
end

function AimDirector.update()
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if camera == nil or character == nil then
		currentTarget = nil
		currentConfidence = 0
		return
	end

	currentTarget, currentConfidence = selectPresentationTarget(camera, character)
	currentAimDir = camera.CFrame.LookVector
end

function AimDirector.reset()
	currentTarget = nil
	currentConfidence = 0
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		currentAimDir = camera.CFrame.LookVector
	end
end

function AimDirector.currentAim(): Vector3
	return currentAimDir
end

function AimDirector.currentTarget(): Model?
	return currentTarget
end

function AimDirector.currentTrajectoryTarget(): Model?
	local character = Players.LocalPlayer.Character
	local localRoot = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or localRoot == nil or not localRoot:IsA("BasePart") then
		return nil
	end
	local direction = currentAimDir
	if direction.Magnitude <= 1e-6 then
		return nil
	end
	direction = direction.Unit
	local origin = localRoot.Position + direction * 2
	local localTeamId = character:GetAttribute("TeamId")
	local row = deviceRow()
	local cosCone = math.cos(math.rad(row.SelectionConeDeg))
	local list = AimDirector.candidates()
	refreshTrajectoryExclusions(list)

	local best: Model? = nil
	local bestId: string? = nil
	local bestScore = math.huge
	for _, candidate in list do
		local targetCharacter = candidate.character
		local root = trajectoryRoot(candidate, localTeamId)
		if root == nil then
			continue
		end
		local offset = root.Position - origin
		local distance = offset.Magnitude
		if distance <= 1e-6 or distance > Combat.Dodgeball.TargetSelectRange then
			continue
		end
		local dot = direction:Dot(offset / distance)
		if dot < cosCone or not trajectoryVisible(origin, root) then
			continue
		end
		local score = math.acos(math.clamp(dot, -1, 1)) + distance * 1e-3
		local id = candidate.id
		if score < bestScore or (score == bestScore and (bestId == nil or id < bestId)) then
			best = targetCharacter
			bestId = id
			bestScore = score
		end
	end
	return best
end

function AimDirector.targetMotion(target: Model): (Vector3?, number)
	local root = target:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, 0
	end
	local samples = velocityHistories[target]
	return root.AssemblyLinearVelocity, if samples ~= nil then Intercept.consistency(samples) else 0
end

function AimDirector.currentConfidence(): number
	return if currentTarget == nil then 0 else currentConfidence
end

return AimDirector
