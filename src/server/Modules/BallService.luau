-- Name: BallService.luau
-- Author: Jack C.
-- Description: The only creator of ball instances: clones the Studio-authored default ball into the world balls folder, grants held balls to match entrants, seeds their sim attributes, and handles recovery and timed ground spawns.
-- Created: 2026-07-13

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

local BallService = {}

local BALLS_FOLDER_NAME = "Balls"

local folder: Folder? = nil
local template: BasePart? = nil
local sequence = 0
local started = false
local recoveryPoints: { BasePart } = {}
local recoveryThreshold: number? = nil
local groundSpawnPoints: { BasePart } = {}
local groundSpawnEnabled = false

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

-- Removes every ball a player owns. Ball lifetime belongs to this service, so
-- callers that need a player emptyhanded ask here rather than destroying
-- instances they did not create.
function BallService.clearOwned(player: Player): number
	local playerId = PlayerIds.toId(player)
	local removed = 0
	for _, ball in ballsFolder():GetChildren() do
		if ball:IsA("BasePart") and ball:GetAttribute("ow") == playerId then
			ball:Destroy()
			removed += 1
		end
	end
	return removed
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

	task.spawn(function()
		while started do
			if recoveryThreshold and #recoveryPoints > 0 then
				for _, inst in pairs(ballsFolder():GetChildren()) do
					if inst:IsA("BasePart") then
						local ph = inst:GetAttribute("ph")
						if type(ph) == "number" and ph >= 5 then
							local posY = inst.CFrame.Position.Y
							if posY < recoveryThreshold then
								local point = recoveryPoints[1]
								if point and point:IsA("BasePart") then
									local expected = point.Position + Vector3.new(0, Combat.Dodgeball.Radius, 0)
									inst.CFrame = CFrame.new(expected)
									inst:SetAttribute("er", Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness)
									inst:SetAttribute("hb", nil)
									inst:SetAttribute("ow", nil)
									inst.Parent = ballsFolder()
								end
							end
						end
					end
				end
			end
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while started do
			if groundSpawnEnabled and #groundSpawnPoints > 0 then
				for _, point in ipairs(groundSpawnPoints) do
					if point and point:IsA("BasePart") then
						local expected = point.Position + Vector3.new(0, Combat.Dodgeball.Radius, 0)
						local occupied = false
						for _, inst in pairs(ballsFolder():GetChildren()) do
							if inst:IsA("BasePart") and (inst.CFrame.Position - expected).Magnitude < 0.1 then
								occupied = true
								break
							end
						end
						if not occupied then
							local ball = spawnBall(CFrame.new(expected))
							ball:SetAttribute("ph", 5)
							ball:SetAttribute("hb", nil)
							ball:SetAttribute("ow", nil)
							ball.Parent = ballsFolder()
						end
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

function BallService.configureRecovery(points: { BasePart }, threshold: number)
	recoveryPoints = points or {}
	recoveryThreshold = threshold
end

function BallService.clearRecovery()
	recoveryPoints = {}
	recoveryThreshold = nil
end

function BallService.startGroundSpawns(points: { BasePart })
	groundSpawnPoints = points or {}
	groundSpawnEnabled = true
end

function BallService.stopGroundSpawns()
	groundSpawnEnabled = false
	groundSpawnPoints = {}
end

return BallService
