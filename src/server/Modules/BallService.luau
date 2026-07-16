--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local PlayerIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds")
)

-- Sole creator of ball instances. Balls enter the world here (outside the
-- deterministic sim — spawning is not input-driven) and join the sim as
-- instances via replication. Two provisioning strategies, driven by the
-- active game mode: cadence ground spawns at map points, and direct held
-- grants to players.

local BallService = {}

local BALLS_FOLDER_NAME = "Balls"

local folder: Folder? = nil
local template: BasePart? = nil
local activePoints: { BasePart }? = nil
local timers: { [BasePart]: number } = {}
local sequence = 0

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
		local default = Cosmetics.Defaults.BallAssets
		local asset = ReplicatedStorage:WaitForChild("Assets")
			:WaitForChild("Cosmetics")
			:WaitForChild(Cosmetics.CategoryFolders.BallAssets)
			:WaitForChild(default.AssetName)
		assert(asset:IsA("BasePart"), "[BallService] default BallAssets asset must be a BasePart")
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

local function hasFreeBallNear(position: Vector3, radius: number): boolean
	for _, ball in ballsFolder():GetChildren() do
		if ball:IsA("BasePart") and ball:GetAttribute("ph") == 6 then
			if vector.magnitude(ball.CFrame.Position - position) <= radius then
				return true
			end
		end
	end
	return false
end

function BallService.startGroundSpawns(points: { BasePart })
	activePoints = points
	table.clear(timers)
end

function BallService.stopGroundSpawns()
	activePoints = nil
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
	ballsFolder()

	RunService.Heartbeat:Connect(function(dt: number)
		local points = activePoints
		if points == nil then
			return
		end
		local cfg = Combat.Dodgeball
		for _, point in points do
			local timer = (timers[point] or 0) - dt
			timers[point] = timer
			if timer > 0 then
				continue
			end
			timers[point] = cfg.SpawnCadence

			local position = point.Position + Vector3.new(0, cfg.Radius, 0)
			if hasFreeBallNear(position, cfg.SpawnSearchRadius) then
				continue
			end

			local ball = spawnBall(CFrame.new(position))
			ball:SetAttribute("ph", 6)
			ball.Parent = ballsFolder()
		end
	end)
end

return BallService
