--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

-- World ball spawning is a plain server service, deliberately outside the
-- deterministic sim: spawns are not input-driven, so clients have nothing to
-- predict — new balls arrive via replication and join the sim as instances.

local BallSpawner = {}

local BALLS_FOLDER_NAME = "Balls"
local SPAWN_TAG = "BallSpawn"

local function ensureFolder(): Folder
	local existing = Workspace:FindFirstChild(BALLS_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = BALLS_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function hasFreeBallNear(folder: Folder, position: Vector3, radius: number): boolean
	for _, ball in folder:GetChildren() do
		if ball:IsA("BasePart") and ball:GetAttribute("ph") == 5 then
			if vector.magnitude(ball.CFrame.Position - position) <= radius then
				return true
			end
		end
	end
	return false
end

local function shallowSearch(parent: Instance, target: string): { Instance? }
	local res = {}
	for _, child in parent:GetChildren() do
		if child.Name == target then
			table.insert(res, child)
		end
	end
	return res
end

function BallSpawner.start()
	local cfg = Combat.Dodgeball
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Dodgeball")
	assert(template:IsA("BasePart"), "[BallSpawner] Assets.Dodgeball must be a BasePart")

	local folder = ensureFolder()
	local spawnPoints = shallowSearch(workspace.CombatTestArena, "BallSpawn")
	if #spawnPoints == 0 then
		warn(`[BallSpawner] no parts named "{SPAWN_TAG}" under CombatTestArena — no world balls will spawn`)
	end

	local timers: { [Instance]: number } = {}
	local sequence = 0

	RunService.Heartbeat:Connect(function(dt: number)
		for _, point in spawnPoints do
			if not point:IsA("BasePart") then
				continue
			end
			local timer = (timers[point] or 0) - dt
			timers[point] = timer
			if timer > 0 then
				continue
			end
			timers[point] = cfg.SpawnCadence

			local position = point.CFrame.Position + Vector3.new(0, cfg.Radius, 0)
			if hasFreeBallNear(folder, position, cfg.SpawnSearchRadius) then
				continue
			end

			sequence += 1
			local ball = template:Clone()
			local authoredRotation = ball.CFrame.Rotation
			ball.Name = string.format("ball_%04d", sequence)
			ball.Anchored = true
			ball.CFrame = CFrame.new(position)
			ball:SetAttribute("ph", 5)
			ball:SetAttribute("er", cfg.Radius + cfg.HitForgiveness)
			ball:SetAttribute("ft", 0)
			ball:SetAttribute("vel", Vector3.zero)
			ball:SetAttribute("wu", 0)
			ball:SetAttribute("bc", 0)
			ball:SetAttribute("sa", 0)
			ball:SetAttribute("sr", 0)
			ball:SetAttribute("ar", authoredRotation)
			ball.Parent = folder
		end
	end)
end

return BallSpawner
