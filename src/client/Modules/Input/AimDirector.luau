--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AimAssist"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

-- The client's single source of aim truth. Desktop: aim = camera look, target
-- is the predicted soft-lock highlight. Touch: aim = direction from the
-- character to an auto-acquired target (camera look fallback), with sticky
-- hysteresis so the lock doesn't flicker. InputRouter feeds the aim into the
-- Aim action; TargetingUI renders the target.

local AimDirector = {}

local currentTarget: Model? = nil
local currentAimDir: Vector3 = Vector3.zAxis

function AimDirector.deviceClass(): string
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch then
		return "Touch"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Mouse"
end

local function deviceRow(): AimAssist.DeviceRow
	return AimAssist[AimDirector.deviceClass()] or AimAssist.Mouse
end

local function isVisible(camera: Camera, character: Model, targetRoot: BasePart, balls: Instance?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if balls then { character, balls } else { character }
	params.RespectCanCollide = true
	local offset = targetRoot.Position - camera.CFrame.Position
	local hit = Workspace:Raycast(camera.CFrame.Position, offset, params)
	return hit == nil or hit.Instance:IsDescendantOf(targetRoot.Parent :: Instance)
end

local function angleFromLook(camera: Camera, position: Vector3): number
	local offset = position - camera.CFrame.Position
	if offset.Magnitude <= 1e-4 then
		return 0
	end
	return math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
end

local function candidateRoot(character: Model, localTeamId: any): BasePart?
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

local function selectTarget(camera: Camera, character: Model): Model?
	local row = deviceRow()
	local balls = Workspace:FindFirstChild("Balls")
	local localTeamId = character:GetAttribute("TeamId")
	local localRoot = character:FindFirstChild("HumanoidRootPart")
	if localRoot == nil or not localRoot:IsA("BasePart") then
		return nil
	end

	local best: Model? = nil
	local bestScore = math.huge
	for _, player in Players:GetPlayers() do
		local targetCharacter = player.Character
		if player == Players.LocalPlayer or targetCharacter == nil then
			continue
		end
		local root = candidateRoot(targetCharacter, localTeamId)
		if root == nil then
			continue
		end
		local distance = (root.Position - localRoot.Position).Magnitude
		if distance <= 0 or distance > Combat.Dodgeball.TargetSelectRange then
			continue
		end

		local angle = angleFromLook(camera, root.Position)
		local coneDeg = if targetCharacter == currentTarget then row.StickyConeDeg else row.AcquireConeDeg
		if angle > coneDeg then
			continue
		end
		if not isVisible(camera, character, root, balls) then
			continue
		end

		-- Same score shape as the sim's selectTarget (radians + small distance
		-- tiebreak) so the highlight predicts the server's pick; the sticky
		-- bias keeps the current lock unless a rival is clearly better.
		local score = math.rad(angle) + distance * 1e-3 - (if targetCharacter == currentTarget then 0.15 else 0)
		if score < bestScore then
			best = targetCharacter
			bestScore = score
		end
	end
	return best
end

function AimDirector.update()
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if camera == nil or character == nil then
		currentTarget = nil
		return
	end

	currentTarget = selectTarget(camera, character)

	if AimDirector.deviceClass() == "Touch" then
		local target = currentTarget
		local localRoot = character:FindFirstChild("HumanoidRootPart")
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
		if localRoot and localRoot:IsA("BasePart") and targetRoot and targetRoot:IsA("BasePart") then
			local offset = targetRoot.Position - localRoot.Position
			if offset.Magnitude > 1e-4 then
				currentAimDir = offset.Unit
				return
			end
		end
	end
	currentAimDir = camera.CFrame.LookVector
end

function AimDirector.currentAim(): Vector3
	return currentAimDir
end

function AimDirector.currentTarget(): Model?
	return currentTarget
end

return AimDirector
