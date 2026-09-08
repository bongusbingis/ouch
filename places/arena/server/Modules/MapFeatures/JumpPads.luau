-- Description: Map feature kit for trampolines: launches players who jump from or fall fast onto an authored pad, cancelling part of gravity for the floaty arc and broadcasting the impulse that drives the client squash effect.

--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local MapFeatureKit = require(script.Parent.MapFeatureKit)
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)

local JumpPads = {}

local ATTACHMENT_NAME = "JumpPadFloatAttachment"
local FORCE_NAME = "JumpPadFloatForce"

type Bounce = {
	force: VectorForce,
	attachment: Attachment,
	root: BasePart,
	expiresAt: number,
	hasLeftGround: boolean,
}

local bounces: { [Player]: Bounce } = {}
local cooldowns: { [Player]: number } = {}

JumpPads.folderName = "JumpPads"
JumpPads.instanceClass = "Model"

local function config()
	return MapFeatures.JumpPad
end

local function clearBounce(player: Player)
	local bounce = bounces[player]
	if bounce == nil then
		return
	end
	bounces[player] = nil
	bounce.force:Destroy()
	bounce.attachment:Destroy()
end

local function emitCloud(root: BasePart)
	local vfx = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX")
	local template = vfx:WaitForChild("CloudJumpParticleEmitter")
	assert(template:IsA("ParticleEmitter"), "[JumpPads] Assets.VFX.CloudJumpParticleEmitter must be a ParticleEmitter")

	local anchor = root:FindFirstChild("RootRigAttachment") or root
	local emitter = template:Clone()
	emitter.Parent = anchor
	emitter:Emit(config().ParticleBurst)
	Debris:AddItem(emitter, config().ParticleLifetime)
end

local function launch(player: Player, root: BasePart, humanoid: Humanoid, pad: Model)
	local settings = config()

	clearBounce(player)

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, settings.BouncePower, velocity.Z)
	MovementGuard.allow(root, "JumpPad", settings.MaxFloatSeconds + 1, 0, settings.BouncePower * 1.3)

	local attachment = Instance.new("Attachment")
	attachment.Name = ATTACHMENT_NAME
	attachment.Parent = root

	local force = Instance.new("VectorForce")
	force.Name = FORCE_NAME
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = true
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * settings.FloatFactor, 0)
	force.Parent = root

	bounces[player] = {
		force = force,
		attachment = attachment,
		root = root,
		expiresAt = os.clock() + settings.MaxFloatSeconds,
		hasLeftGround = false,
	}
	cooldowns[player] = os.clock() + settings.RetriggerCooldown

	emitCloud(root)
	Network.fire("JumpPadImpulse", nil, pad)
end

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.RespectCanCollide = true

function JumpPads.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end

	local bounce = bounces[player]
	if bounce and humanoid.FloorMaterial == Enum.Material.Air then
		bounce.hasLeftGround = true
	end
	if
		bounce ~= nil
		and (
			(bounce.hasLeftGround and humanoid.FloorMaterial ~= Enum.Material.Air)
			or bounce.root ~= root
			or context.now >= bounce.expiresAt
		)
	then
		clearBounce(player)
	end

	if context.now < (cooldowns[player] or 0) then
		return
	end

	local jumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping
	local falling = root.AssemblyLinearVelocity.Y <= -config().FallSpeed
	if not jumping and not falling then
		return
	end
	castParams.FilterDescendantsInstances = { character }
	local distance = humanoid.HipHeight + root.Size.Y / 2 + config().ContactTolerance
	local support = Workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), castParams)
	if support == nil then
		return
	end
	for _, instance in context.instances do
		local pad = instance :: Model
		if support.Instance:IsDescendantOf(pad) then
			launch(player, root, humanoid, pad)
			return
		end
	end
end

function JumpPads.forget(player: Player?)
	if player then
		clearBounce(player)
		cooldowns[player] = nil
		return
	end
	for existing in bounces do
		clearBounce(existing)
	end
	table.clear(cooldowns)
end

return JumpPads
