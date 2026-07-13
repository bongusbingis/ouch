--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local WorldAudio = require(script.Parent.WorldAudio)

local BallVisuals = {}

local visuals: { [BasePart]: BasePart } = {}
local seen: { [string]: boolean } = {}

local function cframeOffset(offset: vector): CFrame
	return CFrame.new(offset.x, offset.y, offset.z)
end

local function characterForPlayerId(playerId: string?): Model?
	if playerId == nil then
		return nil
	end
	for _, player in Players:GetPlayers() do
		if tostring(player.UserId) == playerId then
			return player.Character
		end
	end
	return nil
end

local function rightHand(character: Model?): BasePart?
	if character == nil then
		return nil
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

local function heldVisualCFrame(ball: BasePart): CFrame?
	local character = characterForPlayerId(ball:GetAttribute("hb") :: string?)
	local hand = rightHand(character)
	if hand then
		return hand.CFrame * cframeOffset(Combat.Dodgeball.HeldVisualHandOffset)
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
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

local function addBall(ball: BasePart)
	if visuals[ball] then
		return
	end
	local visual = ball:Clone()
	visual.Name = `{ball.Name}_Visual`
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Parent = Workspace.CurrentCamera
	ball.LocalTransparencyModifier = 1
	visuals[ball] = visual
end

local function removeBall(ball: BasePart)
	local visual = visuals[ball]
	if visual then
		visual:Destroy()
	end
	visuals[ball] = nil
end

function BallVisuals.onEvent(event: any)
	local key = `{event.tick}:{event.kind}:{event.projectileId or ""}`
	if seen[key] then
		return
	end
	seen[key] = true
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
		BallRecallStarted = "Recall",
		Elim = "Hit",
	}
	local effect = effectNames[event.kind]
	if effect then
		playOptional(visual, effect)
	end
end

function BallVisuals.start()
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
