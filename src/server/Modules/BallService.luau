--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local CosmeticVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)
local PlayerIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds")
)

-- Sole creator of replicated ball instances. Provisioning is outside the
-- deterministic sim and currently grants one persistent ball per entrant.

local BallService = {}

local BALLS_FOLDER_NAME = "Balls"

local folder: Folder? = nil
local template: BasePart? = nil
local sequence = 0
local started = false

local function ballsFolder(): Folder
	if folder then
		return folder
	end
	local existing = Workspace:FindFirstChild(BALLS_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = BALLS_FOLDER_NAME
		created.Parent = Workspace
		folder = created
	end
	return folder :: Folder
end

local function ballTemplate(): BasePart
	if template == nil then
		local asset = CosmeticVisualFactory.create("BallAssets", nil)
		assert(not asset.CanCollide, "[BallService] default BallAssets asset must have CanCollide disabled")
		assert(not asset.CanTouch, "[BallService] default BallAssets asset must have CanTouch disabled")
		assert(not asset.CanQuery, "[BallService] default BallAssets asset must have CanQuery disabled")
		template = asset
	end
	return template :: BasePart
end

local function spawnBall(cframe: CFrame): BasePart
	local cfg = Combat.Dodgeball
	sequence += 1
	local ball = ballTemplate():Clone()
	ball.Name = string.format("ball_%04d", sequence)
	ball.Anchored = true
	ball.CFrame = cframe
	ball:SetAttribute("er", cfg.Radius + cfg.HitForgiveness)
	ball:SetAttribute("ft", 0)
	ball:SetAttribute("vel", Vector3.zero)
	return ball
end

function BallService.hasHeldBall(player: Player): boolean
	local playerId = PlayerIds.toId(player)
	for _, ball in ballsFolder():GetChildren() do
		if ball:IsA("BasePart") and ball:GetAttribute("ph") == 0 and ball:GetAttribute("hb") == playerId then
			return true
		end
	end
	return false
end

function BallService.grantHeldBall(player: Player): boolean
	if BallService.hasHeldBall(player) then
		return false
	end
	local character = player.Character
	if character and character:GetAttribute("CombatAlive") == false then
		return false
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local ball = spawnBall(root.CFrame)
	ball:SetAttribute("ph", 0)
	ball:SetAttribute("hb", PlayerIds.toId(player))
	ball:SetAttribute("ow", PlayerIds.toId(player))
	ball.Parent = ballsFolder()
	return true
end

function BallService.clearAll()
	ballsFolder():ClearAllChildren()
end

function BallService.start()
	if started then
		return
	end
	started = true

	ballsFolder()
end

return BallService
