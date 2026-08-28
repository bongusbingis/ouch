-- Name: TrainingDummies.luau
-- Author: Jack C.
-- Description: Spawns the goofy training dummies and practice bots as real simulation characters, so the dodgeball and hammer hit them by exactly the rules that decide a real match, and owns their knockout, launch, and return.
-- Created: 2026-08-27

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OnboardingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Onboarding"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

local TrainingDummies = {}

-- Dummies share one team id so they never target or block each other, and the
-- player has none, which is what makes every dummy a legal target for them.
TrainingDummies.TeamId = "OnboardingDummies"

local CONTAINER_NAME = "OnboardingDummies"

export type Dummy = {
	id: string,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	homePosition: Vector3,
	-- Extra hit radius granted to this dummy while assistance is escalated.
	forgiveness: number,
	-- Set while the dummy is flying away from a hit; it is not a sim character
	-- again until it returns.
	knockedOutAt: number?,
}

local dummies: { [string]: Dummy } = {}
local sequence = 0

local function container(): Folder
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = CONTAINER_NAME
	created.Parent = Workspace
	return created
end

local function rigTemplate(): Model
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local rigs = assets:WaitForChild("Rigs")
	local rig = rigs:WaitForChild("CharacterRig")
	assert(rig:IsA("Model"), "[TrainingDummies] Assets.Rigs.CharacterRig must be a Model")
	return rig
end

-- PROTOTYPE DRESSING. The dummy is the shipped character rig recoloured and
-- given a bobbing sign; a bespoke inflatable dummy model should replace this.
local function dress(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = OnboardingConfig.Prototype.DummyColor
			descendant.Material = Enum.Material.SmoothPlastic
		elseif descendant:IsA("Shirt") or descendant:IsA("Pants") or descendant:IsA("SurfaceAppearance") then
			descendant:Destroy()
		end
	end
end

local function newDummy(kind: string, position: Vector3, lookAt: Vector3?): Dummy
	sequence += 1
	local id = `dummy_{sequence}`
	local model = rigTemplate():Clone()
	model.Name = id
	dress(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid ~= nil, "[TrainingDummies] the character rig must contain a Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 0
	humanoid.BreakJointsOnDeath = false

	local root = model:FindFirstChild("HumanoidRootPart")
	assert(root ~= nil and root:IsA("BasePart"), "[TrainingDummies] the character rig must contain a HumanoidRootPart")

	-- These are the same attributes a player's character carries: the codec and
	-- the sim read a dummy through exactly the same door.
	model:SetAttribute("CombatAlive", true)
	model:SetAttribute("TeamId", TrainingDummies.TeamId)
	model:SetAttribute("OnboardingDummy", kind)

	model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 3, 0), lookAt or (position + Vector3.new(0, 3, 10))))
	model.Parent = container()

	local dummy: Dummy = {
		id = id,
		model = model,
		root = root :: BasePart,
		humanoid = humanoid :: Humanoid,
		homePosition = position,
		forgiveness = 0,
		knockedOutAt = nil,
	}
	dummies[id] = dummy
	return dummy
end

function TrainingDummies.spawn(kind: string, position: Vector3, lookAt: Vector3?): Dummy
	return newDummy(kind, position, lookAt)
end

function TrainingDummies.get(id: string): Dummy?
	return dummies[id]
end

function TrainingDummies.isDummy(id: string?): boolean
	return id ~= nil and dummies[id] ~= nil
end

-- The character source the adapter reads. A knocked-out dummy is withheld, so
-- the sim treats it as gone rather than as a corpse that can be hit again.
function TrainingDummies.characterSource(): { [string]: any }
	local entries: { [string]: any } = {}
	for id, dummy in dummies do
		if dummy.model.Parent == nil then
			dummies[id] = nil
			continue
		end
		if dummy.knockedOutAt ~= nil then
			continue
		end
		entries[id] = {
			model = dummy.model,
			root = dummy.root,
			player = nil,
			radius = Combat.CharacterCapsule.Radius + dummy.forgiveness,
		}
	end
	return entries
end

function TrainingDummies.setForgiveness(id: string, extraStuds: number)
	local dummy = dummies[id]
	if dummy ~= nil then
		dummy.forgiveness = math.max(extraStuds, 0)
	end
end

-- The comedy beat: a hit dummy squashes, spins, and sails away. It is a
-- presentation move, not a gameplay one, so it happens on the server purely so
-- every client sees the same launch.
function TrainingDummies.knockOut(id: string, direction: Vector3?)
	local dummy = dummies[id]
	if dummy == nil or dummy.knockedOutAt ~= nil then
		return
	end
	dummy.knockedOutAt = os.clock()
	dummy.model:SetAttribute("CombatAlive", false)
	dummy.humanoid.WalkSpeed = 0
	dummy.humanoid.PlatformStand = true

	local launch = direction or Vector3.new(0, 0, 1)
	local flat = Vector3.new(launch.X, 0, launch.Z)
	local unit = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	for _, descendant in dummy.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	dummy.root.Anchored = false
	dummy.root:ApplyImpulse((unit * 40 + Vector3.new(0, 65, 0)) * dummy.root.AssemblyMass)
	dummy.root:ApplyAngularImpulse(Vector3.new(0, 1, 0) * dummy.root.AssemblyMass * 25)
end

function TrainingDummies.isKnockedOut(id: string): boolean
	local dummy = dummies[id]
	return dummy ~= nil and dummy.knockedOutAt ~= nil
end

function TrainingDummies.restore(id: string)
	local dummy = dummies[id]
	if dummy == nil then
		return
	end
	dummy.knockedOutAt = nil
	dummy.root.Anchored = false
	dummy.root.AssemblyLinearVelocity = Vector3.zero
	dummy.root.AssemblyAngularVelocity = Vector3.zero
	for _, descendant in dummy.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = true
		end
	end
	dummy.humanoid.PlatformStand = false
	dummy.model:PivotTo(CFrame.new(dummy.homePosition + Vector3.new(0, 3, 0)))
	dummy.model:SetAttribute("CombatAlive", true)
end

function TrainingDummies.walkTo(id: string, position: Vector3, speed: number)
	local dummy = dummies[id]
	if dummy == nil or dummy.knockedOutAt ~= nil then
		return
	end
	dummy.humanoid.WalkSpeed = speed
	dummy.humanoid:MoveTo(position)
end

function TrainingDummies.stop(id: string)
	local dummy = dummies[id]
	if dummy == nil then
		return
	end
	dummy.humanoid.WalkSpeed = 0
	dummy.humanoid:MoveTo(dummy.root.Position)
end

function TrainingDummies.position(id: string): Vector3?
	local dummy = dummies[id]
	return if dummy then dummy.root.Position else nil
end

function TrainingDummies.despawn(id: string)
	local dummy = dummies[id]
	dummies[id] = nil
	if dummy then
		dummy.model:Destroy()
	end
end

function TrainingDummies.despawnAll(predicate: ((Dummy) -> boolean)?)
	for id, dummy in dummies do
		if predicate == nil or predicate(dummy) then
			TrainingDummies.despawn(id)
		end
	end
end

RunService.Heartbeat:Connect(function()
	-- A dummy launched out of the world is simply removed from the physics
	-- solver's reach; its session decides whether to bring it back.
	for _, dummy in dummies do
		if dummy.knockedOutAt ~= nil and dummy.root.Position.Y < dummy.homePosition.Y - 300 then
			dummy.root.Anchored = true
		end
	end
end)

return TrainingDummies
