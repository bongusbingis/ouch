--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AimAssist"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))

-- The client's single source of aim truth. Aim is the camera look direction on
-- every device: the player always points the camera themselves, and assists
-- only bias what happens afterwards. Touch used to override aim with the
-- direction to an auto-acquired target, which meant the camera was decorative
-- and the throw was not really the player's -- that is what the assists below
-- replace.
--
-- Selection is sticky: acquiring needs the target inside the narrow cone,
-- holding it only needs the wider sticky cone, so a lock does not flicker
-- between two enemies standing near each other. Confidence falls off toward the
-- edge of that cone so every assist that scales by it fades out smoothly rather
-- than snapping off. InputRouter feeds the aim into the Aim action.

local AimDirector = {}

local currentTarget: Model? = nil
local currentAimDir: Vector3 = Vector3.zAxis
local currentConfidence = 0

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

-- 1 dead centre, tapering to 0 at the edge of the cone that holds the lock. The
-- fade start keeps the middle of the cone at full strength so assists do not
-- feel weaker just for being slightly off centre.
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

local function selectTarget(camera: Camera, character: Model): (Model?, number)
	local row = deviceRow()
	local balls = Workspace:FindFirstChild("Balls")
	local localTeamId = character:GetAttribute("TeamId")
	local localRoot = character:FindFirstChild("HumanoidRootPart")
	if localRoot == nil or not localRoot:IsA("BasePart") then
		return nil, 0
	end

	local best: Model? = nil
	local bestScore = math.huge
	local bestConfidence = 0
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

	currentTarget, currentConfidence = selectTarget(camera, character)
	currentAimDir = camera.CFrame.LookVector
end

function AimDirector.currentAim(): Vector3
	return currentAimDir
end

function AimDirector.currentTarget(): Model?
	return currentTarget
end

-- 0-1 confidence in the current target. Zero whenever there is none.
function AimDirector.currentConfidence(): number
	return if currentTarget == nil then 0 else currentConfidence
end

return AimDirector
