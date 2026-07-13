--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local WorldAudio = require(script.Parent.WorldAudio)

local HammerVisuals = {}

local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Hammer")
assert(template:IsA("BasePart"), "[HammerVisuals] Assets.Hammer must be a BasePart")

local visuals: { [Player]: BasePart } = {}
local ballsFolder = Workspace:WaitForChild("Balls")
local seenEvents: { [string]: boolean } = {}

local function offsetCFrame(): CFrame
	local offset = Combat.Hammer.VisualHandOffset
	local rotation = Combat.Hammer.VisualRotationDeg
	return CFrame.new(offset.x, offset.y, offset.z)
		* CFrame.Angles(math.rad(rotation.x), math.rad(rotation.y), math.rad(rotation.z))
end

local function rightHand(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

local function rootPart(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function hasBall(player: Player): boolean
	local playerId = tostring(player.UserId)
	for _, ball in ballsFolder:GetChildren() do
		if ball:IsA("BasePart") and ball:GetAttribute("hb") == playerId then
			local phase = ball:GetAttribute("ph")
			if phase == 0 or phase == 1 then
				return true
			end
		end
	end
	return false
end

local function remove(player: Player)
	local visual = visuals[player]
	if visual then
		visual:Destroy()
	end
	visuals[player] = nil
end

local function visualFor(player: Player): BasePart
	local visual = visuals[player]
	if visual then
		return visual
	end

	visual = template:Clone()
	visual.Name = `{player.Name}_HammerVisual`
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Parent = Workspace.CurrentCamera
	visuals[player] = visual
	return visual
end

local function audioParentFor(playerId: string): Instance?
	for player, visual in visuals do
		if tostring(player.UserId) == playerId then
			return visual
		end
	end

	for _, player in Players:GetPlayers() do
		if tostring(player.UserId) ~= playerId then
			continue
		end
		local character = player.Character
		if character == nil then
			return nil
		end
		return rightHand(character) or rootPart(character)
	end
	return nil
end

function HammerVisuals.start()
	Players.PlayerRemoving:Connect(remove)

	RunService.RenderStepped:Connect(function()
		local grip = offsetCFrame()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character == nil then
				remove(player)
				continue
			end

			local hand = rightHand(character)
			if hand == nil or hasBall(player) then
				remove(player)
				continue
			end

			visualFor(player).CFrame = hand.CFrame * grip
		end
	end)
end

function HammerVisuals.onEvent(event: any)
	local soundNames = {
		HammerSwing = "Swing",
		HammerHit = "Hit",
		HammerMiss = "Miss",
	}
	local soundName = soundNames[event.kind]
	if soundName == nil then
		return
	end

	local key = `{event.tick}:{event.kind}:{event.playerId or ""}:{event.targetId or ""}`
	if seenEvents[key] then
		return
	end
	seenEvents[key] = true

	local playerId = event.playerId or event.sourceId
	if playerId == nil then
		return
	end
	local parent = audioParentFor(playerId)
	if parent then
		WorldAudio.play("Hammer", soundName, parent)
	end
end

return HammerVisuals
