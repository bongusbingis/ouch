-- Description: The only creator of ball instances: clones the Studio-authored default ball into the world balls folder, grants held balls to match entrants, seeds their sim attributes, and handles recovery and timed ground spawns.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
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
local groundSpawnReadyAt: { [BasePart]: number } = {}
local random: Random? = nil

local function recoveryIndex(count: number): number
	local generator = random
	if generator == nil then
		generator = Random.new()
		random = generator
	end
	return generator:NextInteger(1, count)
end

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
	table.clear(groundSpawnReadyAt)
end

local GROUND_SPAWN_POLL_SECONDS = 0.5

-- Replenishment, bounded three ways so a match cannot silently fill with balls:
-- a point refills at most every SpawnCadence seconds, a point is skipped while a
-- loose ball already sits within SpawnSearchRadius of it, and the world holds at
-- most WorldBallCap loose balls in total. Without this the supply only ever fell,
-- because nothing else puts a ball back into a round in progress.
local function replenishGroundBalls(now: number)
	local cfg = Combat.Dodgeball
	local loose = {}
	for _, inst in ballsFolder():GetChildren() do
		local phase = inst:GetAttribute("ph")
		if inst:IsA("BasePart") and type(phase) == "number" and phase >= 5 then
			table.insert(loose, inst.Position)
		end
	end
	if #loose >= cfg.WorldBallCap then
		return
	end

	for _, point in groundSpawnPoints do
		if not point:IsA("BasePart") or point.Parent == nil then
			continue
		end
		local readyAt = groundSpawnReadyAt[point]
		if readyAt ~= nil and now < readyAt then
			continue
		end
		local expected = point.Position + Vector3.new(0, cfg.Radius, 0)
		local occupied = false
		for _, position in loose do
			if (position - expected).Magnitude <= cfg.SpawnSearchRadius then
				occupied = true
				break
			end
		end
		if occupied then
			-- Still stocked, so the cadence has not started running down yet.
			groundSpawnReadyAt[point] = nil
			continue
		end
		if readyAt == nil then
			groundSpawnReadyAt[point] = now + cfg.SpawnCadence
			continue
		end

		local ball = spawnBall(CFrame.new(expected))
		ball:SetAttribute("ph", 5)
		ball:SetAttribute("hb", nil)
		ball:SetAttribute("ow", nil)
		ball.Parent = ballsFolder()
		groundSpawnReadyAt[point] = nil
		table.insert(loose, expected)
		if #loose >= cfg.WorldBallCap then
			return
		end
	end
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
								-- Spread over every recovery point rather than always the
								-- first: a match that loses several balls off the same ledge
								-- otherwise stacks them all back in one spot.
								local point = recoveryPoints[recoveryIndex(#recoveryPoints)]
								if point and point:IsA("BasePart") then
									local expected = point.Position + Vector3.new(0, Combat.Dodgeball.Radius, 0)
									inst.CFrame = CFrame.new(expected)
									inst:SetAttribute("er", Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness)
									inst:SetAttribute("vel", Vector3.zero)
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
				replenishGroundBalls(os.clock())
			end
			task.wait(GROUND_SPAWN_POLL_SECONDS)
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
	table.clear(groundSpawnReadyAt)
end

function BallService.stopGroundSpawns()
	groundSpawnEnabled = false
	groundSpawnPoints = {}
	table.clear(groundSpawnReadyAt)
end

return BallService
