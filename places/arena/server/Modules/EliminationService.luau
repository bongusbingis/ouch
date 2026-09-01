-- Name: EliminationService.luau
-- Author: Jack C.
-- Description: Owns eliminated character body state without touching Humanoid health or reloading the character: flips the CombatAlive attribute, builds and removes the ragdoll constraints, and restores the saved joint and physics state.
-- Created: 2026-07-13

--!strict

local EliminationService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

type HumanoidState = {
	AutoRotate: boolean,
	PlatformStand: boolean,
	RequiresNeck: boolean,
	BreakJointsOnDeath: boolean,
	GettingUpEnabled: boolean,
}

type PartState = {
	CanCollide: boolean,
	CanQuery: boolean,
	CanTouch: boolean,
	Massless: boolean,
}

type RagdollState = {
	Motors: { Motor6D },
	Instances: { Instance },
	HumanoidState: HumanoidState?,
	PartStates: { [BasePart]: PartState },
}

local active: { [Model]: RagdollState } = {}

local JOINT_LIMITS = {
	Neck = { UpperAngle = 25, TwistLowerAngle = -20, TwistUpperAngle = 20 },
	Waist = { UpperAngle = 35, TwistLowerAngle = -25, TwistUpperAngle = 25 },

	LeftShoulder = { UpperAngle = 80, TwistLowerAngle = -45, TwistUpperAngle = 45 },
	RightShoulder = { UpperAngle = 80, TwistLowerAngle = -45, TwistUpperAngle = 45 },
	LeftElbow = { UpperAngle = 25, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	RightElbow = { UpperAngle = 25, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	LeftWrist = { UpperAngle = 25, TwistLowerAngle = -20, TwistUpperAngle = 20 },
	RightWrist = { UpperAngle = 25, TwistLowerAngle = -20, TwistUpperAngle = 20 },

	LeftHip = { UpperAngle = 55, TwistLowerAngle = -25, TwistUpperAngle = 25 },
	RightHip = { UpperAngle = 55, TwistLowerAngle = -25, TwistUpperAngle = 25 },
	LeftKnee = { UpperAngle = 25, TwistLowerAngle = -5, TwistUpperAngle = 5 },
	RightKnee = { UpperAngle = 25, TwistLowerAngle = -5, TwistUpperAngle = 5 },
	LeftAnkle = { UpperAngle = 25, TwistLowerAngle = -15, TwistUpperAngle = 15 },
	RightAnkle = { UpperAngle = 25, TwistLowerAngle = -15, TwistUpperAngle = 15 },

	Default = { UpperAngle = 45, TwistLowerAngle = -25, TwistUpperAngle = 25 },
}

local function setCombatState(player: Player, character: Model, alive: boolean)
	local health = if alive then Combat.Elimination.MaxHealth else 0
	player:SetAttribute("CombatAlive", alive)
	player:SetAttribute("CombatHealth", health)
	character:SetAttribute("CombatAlive", alive)
	character:SetAttribute("CombatHealth", health)
end

local function humanoidOf(character: Model): Humanoid?
	return character:FindFirstChildOfClass("Humanoid")
end

local function setNetworkOwnerServer(part: BasePart)
	local ok, canSet = pcall(part.CanSetNetworkOwnership, part)
	if ok and canSet then
		pcall(part.SetNetworkOwner, part, nil)
	end
end

local function applyPartPhysics(character: Model, state: RagdollState)
	local root = character:FindFirstChild("HumanoidRootPart")
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		state.PartStates[descendant] = {
			CanCollide = descendant.CanCollide,
			CanQuery = descendant.CanQuery,
			CanTouch = descendant.CanTouch,
			Massless = descendant.Massless,
		}
		descendant.Anchored = false
		setNetworkOwnerServer(descendant)

		if descendant == root then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant.Parent and descendant.Parent:IsA("Accessory") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
		else
			descendant.CanCollide = true
			descendant.CanTouch = false
		end
	end
end

local function restorePartPhysics(state: RagdollState)
	for part, partState in state.PartStates do
		if part.Parent == nil then
			continue
		end
		part.CanCollide = partState.CanCollide
		part.CanQuery = partState.CanQuery
		part.CanTouch = partState.CanTouch
		part.Massless = partState.Massless
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

local function applyHumanoidPhysics(humanoid: Humanoid, state: RagdollState)
	state.HumanoidState = {
		AutoRotate = humanoid.AutoRotate,
		PlatformStand = humanoid.PlatformStand,
		RequiresNeck = humanoid.RequiresNeck,
		BreakJointsOnDeath = humanoid.BreakJointsOnDeath,
		GettingUpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp),
	}

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	pcall(function()
		humanoid.EvaluateStateMachine = false
	end)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

local function restoreHumanoidPhysics(humanoid: Humanoid?, state: RagdollState)
	local humanoidState = state.HumanoidState
	if humanoid == nil or humanoidState == nil then
		return
	end

	humanoid.AutoRotate = humanoidState.AutoRotate
	humanoid.PlatformStand = humanoidState.PlatformStand
	humanoid.RequiresNeck = humanoidState.RequiresNeck
	humanoid.BreakJointsOnDeath = humanoidState.BreakJointsOnDeath
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, humanoidState.GettingUpEnabled)
	pcall(function()
		humanoid.EvaluateStateMachine = true
	end)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local function ragdollImpulsePart(character: Model): BasePart?
	local part = character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
		or character.PrimaryPart
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function applyImpulse(character: Model, impulseVelocity: Vector3?)
	if impulseVelocity == nil or impulseVelocity.Magnitude <= 0 then
		return
	end

	local part = ragdollImpulsePart(character)
	if part == nil then
		return
	end

	part:ApplyImpulseAtPosition(impulseVelocity * part.AssemblyMass, part.Position + Vector3.new(0, 1, 0))
	part:ApplyAngularImpulse(Vector3.new(0, part.AssemblyMass * Combat.Elimination.AngularImpulseY, 0))
end

local function buildJoint(motor: Motor6D, state: RagdollState)
	local part0 = motor.Part0
	local part1 = motor.Part1
	if part0 == nil or part1 == nil then
		return
	end
	if part0.Name == "HumanoidRootPart" or part1.Name == "HumanoidRootPart" then
		return
	end

	local limits = JOINT_LIMITS[motor.Name] or JOINT_LIMITS.Default

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = `Ragdoll_{motor.Name}_A0`
	attachment0.CFrame = motor.C0
	attachment0.Parent = part0

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = `Ragdoll_{motor.Name}_A1`
	attachment1.CFrame = motor.C1
	attachment1.Parent = part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = `Ragdoll_{motor.Name}`
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.LimitsEnabled = true
	socket.TwistLimitsEnabled = true
	socket.UpperAngle = limits.UpperAngle
	socket.TwistLowerAngle = limits.TwistLowerAngle
	socket.TwistUpperAngle = limits.TwistUpperAngle
	socket.MaxFrictionTorque = 0
	socket.Restitution = 0
	socket.Parent = part0

	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Name = `RagdollNoCollision_{motor.Name}`
	noCollision.Part0 = part0
	noCollision.Part1 = part1
	noCollision.Parent = part0

	motor.Enabled = false
	table.insert(state.Motors, motor)
	table.insert(state.Instances, attachment0)
	table.insert(state.Instances, attachment1)
	table.insert(state.Instances, socket)
	table.insert(state.Instances, noCollision)
end

function EliminationService.isDown(character: Model): boolean
	return character:GetAttribute("CombatAlive") == false
end

function EliminationService.down(player: Player, impulseVelocity: Vector3?): boolean
	local character = player.Character
	if character == nil or EliminationService.isDown(character) then
		return false
	end
	local humanoid = humanoidOf(character)
	if humanoid == nil then
		return false
	end

	setCombatState(player, character, false)

	local state: RagdollState = {
		Motors = {},
		Instances = {},
		HumanoidState = nil,
		PartStates = {},
	}
	active[character] = state

	applyHumanoidPhysics(humanoid, state)
	applyPartPhysics(character, state)
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") then
			buildJoint(motor, state)
		end
	end
	applyImpulse(character, impulseVelocity)

	return true
end

function EliminationService.up(player: Player): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	local humanoid = humanoidOf(character)
	local state = active[character]

	if state then
		active[character] = nil
		for _, instance in state.Instances do
			if instance.Parent ~= nil then
				instance:Destroy()
			end
		end
		for _, motor in state.Motors do
			if motor.Parent ~= nil then
				motor.Enabled = true
			end
		end
		restorePartPhysics(state)
		restoreHumanoidPhysics(humanoid, state)
	elseif humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	setCombatState(player, character, true)
	return true
end

return EliminationService
