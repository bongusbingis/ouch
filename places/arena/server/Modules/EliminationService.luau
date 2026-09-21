-- Description: Owns eliminated character body state without touching Humanoid health or reloading the character: flips the CombatAlive attribute, builds and removes the ragdoll constraints, and restores the saved joint and physics state.

--!strict

local EliminationService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))

type PartPhysicsState = {
	Anchored: boolean,
	CanCollide: boolean,
	CanTouch: boolean,
	CanQuery: boolean,
	Massless: boolean,
}

type HumanoidPhysicsState = {
	AutoRotate: boolean,
	PlatformStand: boolean,
	RequiresNeck: boolean,
	BreakJointsOnDeath: boolean,
	EvaluateStateMachine: boolean,
	GettingUpEnabled: boolean,
	State: Enum.HumanoidStateType,
}

type RagdollState = {
	Kind: "Elimination" | "Impact",
	Motors: { [Motor6D]: boolean },
	Instances: { Instance },
	PartPhysics: { [BasePart]: PartPhysicsState },
	HumanoidPhysics: HumanoidPhysicsState,
	CleanupConnection: RBXScriptConnection?,
	RemovalConnection: RBXScriptConnection?,
	DeathConnection: RBXScriptConnection?,
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

-- A character is always owned by its own player, stated outright rather than
-- left to the engine to assign: the ragdoll hands every part to the server, and
-- nothing reloads the character afterwards, so without this the character stays
-- server-simulated for the rest of the session and every input round-trips.
-- Runs over the live descendants, not the saved set, so parts that appeared
-- while the player was down are covered too.
local function claimCharacter(character: Model, player: Player)
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		local ok, canSet = pcall(descendant.CanSetNetworkOwnership, descendant)
		if ok and canSet then
			pcall(descendant.SetNetworkOwner, descendant, player)
		end
	end
end

local function snapshotPartPhysics(character: Model): { [BasePart]: PartPhysicsState }
	local partPhysics = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			partPhysics[descendant] = {
				Anchored = descendant.Anchored,
				CanCollide = descendant.CanCollide,
				CanTouch = descendant.CanTouch,
				CanQuery = descendant.CanQuery,
				Massless = descendant.Massless,
			}
		end
	end
	return partPhysics
end

local function applyPartPhysics(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.Anchored = false
		setNetworkOwnerServer(descendant)

		if descendant == root or descendant.Parent ~= character then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		else
			descendant.CanCollide = true
			descendant.CanTouch = false
		end
	end
end

local function restorePartPhysics(state: RagdollState)
	for part, physics in state.PartPhysics do
		if part.Parent == nil then
			continue
		end
		part.Anchored = physics.Anchored
		part.CanCollide = physics.CanCollide
		part.CanTouch = physics.CanTouch
		part.CanQuery = physics.CanQuery
		part.Massless = physics.Massless
		if state.Kind ~= "Impact" then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function snapshotHumanoidPhysics(humanoid: Humanoid): HumanoidPhysicsState
	return {
		AutoRotate = humanoid.AutoRotate,
		PlatformStand = humanoid.PlatformStand,
		RequiresNeck = humanoid.RequiresNeck,
		BreakJointsOnDeath = humanoid.BreakJointsOnDeath,
		EvaluateStateMachine = humanoid.EvaluateStateMachine,
		GettingUpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp),
		State = humanoid:GetState(),
	}
end

local function applyHumanoidPhysics(humanoid: Humanoid)
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

local function restoreHumanoidPhysics(humanoid: Humanoid?, physics: HumanoidPhysicsState)
	if humanoid == nil then
		return
	end

	humanoid.AutoRotate = physics.AutoRotate
	humanoid.PlatformStand = physics.PlatformStand
	humanoid.RequiresNeck = physics.RequiresNeck
	humanoid.BreakJointsOnDeath = physics.BreakJointsOnDeath
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, physics.GettingUpEnabled)
	local evaluateStateMachine = if humanoid.Health <= 0 then true else physics.EvaluateStateMachine
	pcall(function()
		humanoid.EvaluateStateMachine = evaluateStateMachine
	end)
	humanoid:ChangeState(if humanoid.Health <= 0 then Enum.HumanoidStateType.Dead else physics.State)
	pcall(function()
		humanoid.EvaluateStateMachine = evaluateStateMachine
	end)
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

	state.Motors[motor] = motor.Enabled
	motor.Enabled = false
	table.insert(state.Instances, attachment0)
	table.insert(state.Instances, attachment1)
	table.insert(state.Instances, socket)
	table.insert(state.Instances, noCollision)
end

local function destroyState(character: Model, state: RagdollState)
	if active[character] == state then
		active[character] = nil
	end
	if state.CleanupConnection then
		state.CleanupConnection:Disconnect()
	end
	if state.RemovalConnection then
		state.RemovalConnection:Disconnect()
	end
	if state.DeathConnection then
		state.DeathConnection:Disconnect()
	end
	for _, instance in state.Instances do
		if instance.Parent ~= nil then
			instance:Destroy()
		end
	end
	for motor, enabled in state.Motors do
		if motor.Parent ~= nil then
			motor.Enabled = enabled
		end
	end
	restorePartPhysics(state)
	restoreHumanoidPhysics(humanoidOf(character), state.HumanoidPhysics)
end

local function beginRagdoll(player: Player, character: Model, humanoid: Humanoid, kind: "Elimination" | "Impact")
	local previous = active[character]
	if previous then
		destroyState(character, previous)
	end

	local state: RagdollState = {
		Kind = kind,
		Motors = {},
		Instances = {},
		PartPhysics = snapshotPartPhysics(character),
		HumanoidPhysics = snapshotHumanoidPhysics(humanoid),
	}
	active[character] = state
	state.RemovalConnection = player.CharacterRemoving:Connect(function(removed)
		if removed == character then
			EliminationService.forget(character)
		end
	end)
	state.CleanupConnection = character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			EliminationService.forget(character)
		end
	end)
	state.DeathConnection = humanoid.Died:Connect(function()
		EliminationService.forget(character)
	end)

	applyHumanoidPhysics(humanoid)
	applyPartPhysics(character)
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") then
			buildJoint(motor, state)
		end
	end
	return state
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
	if humanoid.Health <= 0 then
		return true
	end

	beginRagdoll(player, character, humanoid, "Elimination")
	applyImpulse(character, impulseVelocity)

	return true
end

-- A map strike briefly ragdolls a living character without changing combat state.
-- Repeating a strike replaces the active state, so an older expiry cannot restore
-- a newer impact or a subsequent real elimination.
function EliminationService.impact(player: Player, duration: number): boolean
	local character = player.Character
	if character == nil or EliminationService.isDown(character) then
		return false
	end
	local humanoid = humanoidOf(character)
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end

	local state = beginRagdoll(player, character, humanoid, "Impact")
	task.delay(math.max(duration, 0), function()
		if active[character] ~= state or player.Character ~= character then
			return
		end
		local currentHumanoid = humanoidOf(character)
		if character:GetAttribute("CombatAlive") == false or currentHumanoid == nil or currentHumanoid.Health <= 0 then
			return
		end
		destroyState(character, state)
		claimCharacter(character, player)
	end)
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
		destroyState(character, state)
	elseif humanoid and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	if humanoid and humanoid.Health <= 0 then
		setCombatState(player, character, false)
		return false
	end
	claimCharacter(character, player)
	setCombatState(player, character, true)
	return true
end

function EliminationService.forget(character: Model): boolean
	local state = active[character]
	if state == nil then
		return false
	end
	destroyState(character, state)
	return true
end

return EliminationService
