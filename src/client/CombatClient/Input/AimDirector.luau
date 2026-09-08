-- Description: Owns the local player's aim direction and soft-lock target selection each frame, sampling the camera and nearby characters to produce the aim vector, chosen target, target motion, and a confidence score for the rest of the client.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("AimAssist"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local MobileInput =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("MobileInput"))
local SharedGame = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local PlayerIds = require(SharedGame:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local Intercept = require(SharedGame:WaitForChild("Sim"):WaitForChild("Intercept"))
local DeviceClass = require(SharedGame:WaitForChild("Input"):WaitForChild("DeviceClass"))

local AimDirector = {}

type Vec = vector

local currentTarget: Model? = nil
local currentAimDir: Vector3 = Vector3.zAxis
local currentConfidence = 0
local extraTargets: { Model } = {}

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

function AimDirector.deviceClass(): string
	return DeviceClass.current()
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

local function refreshTrajectoryExclusions()
	table.clear(trajectoryExclusions)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(trajectoryExclusions, character)
		end
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

local function trajectoryRoot(player: Player, character: Model, localTeamId: any): BasePart?
	local admission = player:GetAttribute("ArenaAdmission")
	if (admission ~= "Direct" and admission ~= "Matched") or player:GetAttribute("ArenaReady") ~= true then
		return nil
	end
	if character:GetAttribute("minv") == true then
		return nil
	end
	return presentationRoot(character, localTeamId)
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

-- Additional models the reticle may lock onto, registered by whatever owns
-- them. Deliberately not offered to the trajectory target: that one drives the
-- previewed arc's homing, and a preview that curves differently to the throw
-- would teach the wrong thing.
function AimDirector.setExtraTargets(models: { Model })
	extraTargets = models
end

local function selectPresentationTarget(camera: Camera, character: Model): (Model?, number)
	local row = deviceRow()
	local localTeamId = character:GetAttribute("TeamId")
	local localRoot = character:FindFirstChild("HumanoidRootPart")
	if localRoot == nil or not localRoot:IsA("BasePart") then
		return nil, 0
	end
	refreshPresentationExclusions(character)

	local candidates: { Model } = {}
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer and player.Character ~= nil then
			table.insert(candidates, player.Character)
		end
	end
	for _, model in extraTargets do
		if model.Parent ~= nil then
			table.insert(candidates, model)
		end
	end

	local best: Model? = nil
	local bestScore = math.huge
	local bestConfidence = 0
	for _, targetCharacter in candidates do
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
	refreshTrajectoryExclusions()

	local best: Model? = nil
	local bestId: string? = nil
	local bestScore = math.huge
	for _, player in Players:GetPlayers() do
		local targetCharacter = player.Character
		if player == Players.LocalPlayer or targetCharacter == nil then
			continue
		end
		local root = trajectoryRoot(player, targetCharacter, localTeamId)
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
		local id = PlayerIds.toId(player)
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
