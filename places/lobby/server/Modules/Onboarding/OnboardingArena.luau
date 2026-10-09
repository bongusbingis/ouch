-- Description: Owns the training arena instance. Clones the authored TutorialArena once per learner onto a ring far below the lobby, anchors it, and resolves its markers into a layout frame, so every position the training flow asks for is measured from the map the player is actually standing in.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OnboardingConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Onboarding"))
local OnboardingLayout = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingLayout")
)

local OnboardingArena = {}

local CONTAINER_NAME = "OnboardingArenas"

export type Arena = {
	index: number,
	model: Model,
	frame: OnboardingLayout.Frame,
	spawnCFrame: CFrame,
}

local template: Model? = nil

local function resolvedTemplate(): Model
	if template == nil then
		local found = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("TutorialArena")
		assert(found:IsA("Model"), "[OnboardingArena] Assets.Rigs.TutorialArena must be a Model")
		template = found
	end
	return template :: Model
end

local function container(): Folder
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = Workspace
	return folder
end

local function marker(model: Model, name: string): BasePart
	local found = model:WaitForChild("Scriptables"):WaitForChild(name)
	assert(found:IsA("BasePart"), `[OnboardingArena] TutorialArena.Scriptables.{name} must be a BasePart`)
	return found
end

-- Learners are spread around a ring so two sessions can never see, reach, or
-- throw into one another.
function OnboardingArena.slotOrigin(index: number): Vector3
	local world = OnboardingConfig.World
	local ring = math.floor((index - 1) / world.ArenasPerRing)
	local slot = (index - 1) % world.ArenasPerRing
	local angle = (slot / world.ArenasPerRing) * math.pi * 2
	local distance = world.ArenaSpacingStuds * (ring + 1)
	return world.ArenaOrigin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

function OnboardingArena.build(index: number): Arena
	local model = resolvedTemplate():Clone()
	model.Name = `TutorialArena{index}`

	-- The authored map ships almost entirely unanchored, so a clone would
	-- collapse the instant it is parented in. None of it is meant to move.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	local mapOrigin = marker(model, "MapOrigin")
	local playerSpawn = marker(model, "PlayerSpawn")
	model:PivotTo(model:GetPivot() + (OnboardingArena.slotOrigin(index) - mapOrigin.Position))
	model.Parent = container()

	local frame =
		OnboardingLayout.frame(mapOrigin.Position, playerSpawn.Position, OnboardingConfig.World.SurfaceOffsetY)
	local spawnPosition = playerSpawn.Position
	local lookTarget = Vector3.new(frame.origin.x, spawnPosition.Y, frame.origin.z)
	local facing = if (lookTarget - spawnPosition).Magnitude > 1e-3
		then CFrame.lookAt(spawnPosition, lookTarget)
		else CFrame.new(spawnPosition)

	return {
		index = index,
		model = model,
		frame = frame,
		spawnCFrame = facing,
	}
end

function OnboardingArena.point(arena: Arena, distance: number, lateral: number): Vector3
	return OnboardingLayout.point(arena.frame, distance, lateral)
end

function OnboardingArena.ringPoint(arena: Arena, radius: number, index: number, count: number): Vector3
	return OnboardingLayout.ringPoint(arena.frame, radius, index, count)
end

-- A dummy is placed facing the spawn side, which is where the player comes from.
function OnboardingArena.facing(position: Vector3, target: Vector3): CFrame
	local level = Vector3.new(target.X, position.Y, target.Z)
	if (level - position).Magnitude <= 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, level)
end

function OnboardingArena.destroy(arena: Arena?)
	if arena and arena.model.Parent ~= nil then
		arena.model:Destroy()
	end
end

function OnboardingArena.clearAll()
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing then
		existing:Destroy()
	end
end

return OnboardingArena
