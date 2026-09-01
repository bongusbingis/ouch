-- Name: JumpPads.luau
-- Author: Jack C.
-- Description: Map feature kit for trampolines: launches players who jump from or fall fast onto an authored pad, cancelling part of gravity for the floaty arc and broadcasting the impulse that drives the client squash effect.
-- Created: 2026-08-19

--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local MapFeatureKit = require(script.Parent.MapFeatureKit)

local JumpPads = {}

local ATTACHMENT_NAME = "JumpPadFloatAttachment"
local FORCE_NAME = "JumpPadFloatForce"

type Bounce = {
	force: VectorForce,
	attachment: Attachment,
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

	local attachment = Instance.new("Attachment")
	attachment.Name = ATTACHMENT_NAME
	attachment.Parent = root

	local force = Instance.new("VectorForce")
	force.Name = FORCE_NAME
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * settings.FloatFactor, 0)
	force.Parent = root

	bounces[player] = { force = force, attachment = attachment }
	cooldowns[player] = os.clock() + settings.RetriggerCooldown

	emitCloud(root)
	Network.fire("JumpPadImpulse", nil, pad)
end

local function overPad(pad: Model, position: Vector3): boolean
	local settings = config()
	local boundsCFrame, boundsSize = pad:GetBoundingBox()
	local offset = boundsCFrame:PointToObjectSpace(position)
	local top = boundsSize.Y / 2
	return math.abs(offset.X) <= boundsSize.X / 2
		and math.abs(offset.Z) <= boundsSize.Z / 2
		and offset.Y >= -top - settings.VerticalPadding
		and offset.Y <= top + settings.ZoneHeight
end

local function fallingOnto(pad: Model, root: BasePart, humanoid: Humanoid, params: RaycastParams): boolean
	local settings = config()
	if root.AssemblyLinearVelocity.Y > -settings.FallSpeed then
		return false
	end
	params.FilterDescendantsInstances = { pad }
	local distance = humanoid.HipHeight + root.Size.Y / 2 + settings.FallCastBuffer
	return Workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params) ~= nil
end

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Include

function JumpPads.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end

	local bounce = bounces[player]
	if bounce ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air then
		clearBounce(player)
	end

	if context.now < (cooldowns[player] or 0) then
		return
	end

	local jumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping
	for _, instance in context.instances do
		local pad = instance :: Model
		if jumping and overPad(pad, root.Position) then
			launch(player, root, humanoid, pad)
			return
		end
		if fallingOnto(pad, root, humanoid, castParams) then
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
