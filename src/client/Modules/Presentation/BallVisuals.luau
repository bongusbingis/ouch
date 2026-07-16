--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local CharacterRig = require(script.Parent.CharacterRig)
local WorldAudio = require(script.Parent.WorldAudio)

local BallVisuals = {}

local FREE_PHASE = 6

local visuals: { [BasePart]: BasePart } = {}
local appliedAssets: { [BasePart]: string } = {}
local assetTemplates: { [string]: BasePart } = {}
local seen = EventDedup.new(4096)

local function cframeOffset(offset: vector): CFrame
	return CFrame.new(offset.x, offset.y, offset.z)
end

local function characterForPlayerId(playerId: string?): Model?
	local player = PlayerIds.fromId(playerId)
	return player and player.Character
end

local function heldVisualCFrame(ball: BasePart): CFrame?
	local character = characterForPlayerId(ball:GetAttribute("hb") :: string?)
	local hand = CharacterRig.rightHand(character)
	if hand then
		return hand.CFrame * cframeOffset(Combat.Dodgeball.HeldVisualHandOffset)
	end
	local root = CharacterRig.rootPart(character)
	if root then
		return root.CFrame
	end
	return nil
end

local function setEnabled(root: Instance, className: string, enabled: boolean)
	for _, child in root:GetDescendants() do
		if child:IsA(className) then
			(child :: any).Enabled = enabled
		end
	end
end

local function playOptional(ball: BasePart, name: string)
	WorldAudio.play("Dodgeball", name, ball)
	local emitter = ball:FindFirstChild(name, true)
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(emitter:GetAttribute("BurstCount") or 8)
	end
end

-- The ball renders its current owner's equipped asset while possessed (any
-- phase but Free); the default ball look otherwise. Profile truth replicates
-- through the owner's Equip_BallAssets attribute projection.
local function effectiveAssetId(ball: BasePart): string
	if ball:GetAttribute("ph") == FREE_PHASE then
		return ""
	end
	local ownerId = ball:GetAttribute("ow") :: string?
	local userId = if ownerId then tonumber(ownerId) else nil
	local owner = if userId then Players:GetPlayerByUserId(userId) else nil
	if owner == nil then
		return ""
	end
	local itemId = (owner:GetAttribute("Equip_BallAssets") :: string?) or ""
	return if assetTemplates[itemId] ~= nil then itemId else ""
end

local function buildVisual(ball: BasePart, assetId: string): BasePart
	local template = assetTemplates[assetId]
	local visual: BasePart
	if template then
		visual = template:Clone()
		-- Effect children (emitters/sounds/trails) live on the base ball
		-- template; carry them onto the skinned shell.
		for _, child in ball:GetChildren() do
			child:Clone().Parent = visual
		end
	else
		visual = ball:Clone()
	end
	visual.Name = `{ball.Name}_Visual`
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Parent = Workspace.CurrentCamera
	return visual
end

local function addBall(ball: BasePart)
	if visuals[ball] then
		return
	end
	local assetId = effectiveAssetId(ball)
	local visual = buildVisual(ball, assetId)
	ball.LocalTransparencyModifier = 1
	visuals[ball] = visual
	appliedAssets[ball] = assetId
end

local function removeBall(ball: BasePart)
	local visual = visuals[ball]
	if visual then
		visual:Destroy()
	end
	visuals[ball] = nil
	appliedAssets[ball] = nil
end

local function refreshAsset(ball: BasePart)
	local assetId = effectiveAssetId(ball)
	if appliedAssets[ball] == assetId then
		return
	end
	local previous = visuals[ball]
	local visual = buildVisual(ball, assetId)
	if previous then
		visual.CFrame = previous.CFrame
		previous:Destroy()
	end
	visuals[ball] = visual
	appliedAssets[ball] = assetId
end

function BallVisuals.onEvent(event: any)
	if not seen.markSeen(event) then
		return
	end
	local folder = Workspace:FindFirstChild("Balls")
	local ball = folder and event.projectileId and folder:FindFirstChild(event.projectileId)
	local visual = if ball and ball:IsA("BasePart") then visuals[ball] else nil
	if visual == nil then
		return
	end
	local effectNames = {
		BallWindup = "Windup",
		BallReleased = "Throw",
		BallBounced = "Bounce",
		BallSettled = "Landing",
		BallPickedUp = "Pickup",
		BallCaught = "Pickup",
		BallRecallStarted = "Recall",
		Elim = "Hit",
	}
	local effect = effectNames[event.kind]
	if effect then
		playOptional(visual, effect)
	end
end

function BallVisuals.start()
	local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
		:WaitForChild("Cosmetics")
		:WaitForChild(Cosmetics.CategoryFolders.BallAssets)
	for itemId, item in Cosmetics.Items do
		if item.Category == "BallAssets" then
			local template = assetsFolder:WaitForChild(item.AssetName)
			assert(template:IsA("BasePart"), `[BallVisuals] asset template {item.AssetName} must be a BasePart`)
			assetTemplates[itemId] = template
		end
	end

	local folder = Workspace:WaitForChild("Balls")
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			addBall(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			addBall(child)
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			removeBall(child)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local alpha = 1 - math.exp(-Combat.Dodgeball.RemoteSmoothing * dt)
		local localId = tostring(Players.LocalPlayer.UserId)
		for ball, visual in visuals do
			if ball.Parent == nil then
				removeBall(ball)
				continue
			end
			refreshAsset(ball)
			visual = visuals[ball] :: BasePart
			local phase = ball:GetAttribute("ph")
			local heldCFrame = if phase == 0 or phase == 1 then heldVisualCFrame(ball) else nil
			local immediate = ball:GetAttribute("hb") == localId or phase == 1
			local targetCFrame = heldCFrame or ball.CFrame
			visual.CFrame = if immediate then targetCFrame else visual.CFrame:Lerp(targetCFrame, alpha)
			setEnabled(visual, "Trail", phase == 2 or phase == 3 or phase == 5)
		end
	end)
end

return BallVisuals
