-- Description: Owns the training dummies from spawn to removal: clones the authored character rig, walks it at its learner with the Humanoid, holds it at arm's length so it can never shove them, and knocks it flying when it is hit. A dummy's standing-or-knocked state lives here and nowhere else.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local OnboardingConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Onboarding"))

local OnboardingDummies = {}

local TARGET_ATTRIBUTE = OnboardingConfig.TargetAttribute

export type Dummy = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	radius: number,
	knocked: boolean,
	repathAt: number,
}

local rigTemplate: Model? = nil
local idleAnimation: Animation? = nil

local function assets(): Instance
	return ReplicatedStorage:WaitForChild("Assets")
end

local function resolvedRig(): Model
	if rigTemplate == nil then
		local found = assets():WaitForChild("Rigs"):WaitForChild("CharacterRig")
		assert(found:IsA("Model"), "[OnboardingDummies] Assets.Rigs.CharacterRig must be a Model")
		rigTemplate = found
	end
	return rigTemplate :: Model
end

local function resolvedIdle(): Animation
	if idleAnimation == nil then
		local found = assets():WaitForChild("Animations"):WaitForChild("Idle")
		assert(found:IsA("Animation"), "[OnboardingDummies] Assets.Animations.Idle must be an Animation")
		idleAnimation = found
	end
	return idleAnimation :: Animation
end

function OnboardingDummies.spawn(cframe: CFrame, parent: Instance, walkSpeed: number, ownerId: string): Dummy
	local model = resolvedRig():Clone()
	model.Name = "TrainingDummy"

	local humanoid = model:WaitForChild("Humanoid")
	local root = model:WaitForChild("HumanoidRootPart")
	assert(humanoid:IsA("Humanoid"), "[OnboardingDummies] CharacterRig.Humanoid must be a Humanoid")
	assert(root:IsA("BasePart"), "[OnboardingDummies] CharacterRig.HumanoidRootPart must be a BasePart")

	-- A dummy walks, so it stays unanchored and keeps its mass; the standoff
	-- distance rather than masslessness is what stops it shoving the player.
	-- Clothing and body colours are stripped so the rig reads as one flat
	-- silhouette, which is the only part of this that survives a device with
	-- effects turned off.
	local style = OnboardingConfig.Dummy
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
		if descendant:IsA("MeshPart") then
			descendant.Color = style.BodyColor
		end
		if descendant:IsA("Shirt") or descendant:IsA("Pants") or descendant:IsA("BodyColors") then
			descendant:Destroy()
		end
	end

	humanoid.WalkSpeed = walkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	model.PrimaryPart = root
	model.Parent = parent
	-- The caller names a point on the ground, but PivotTo places the root, which
	-- stands a rig's worth above the feet. Without this a dummy spawns buried to
	-- the waist; the clearance drops it the last stud or two onto the floor.
	local lift = root.Size.Y * 0.5 + humanoid.HipHeight + OnboardingConfig.Training.DummySpawnClearanceStuds
	model:PivotTo(cframe + Vector3.new(0, lift, 0))

	-- A highlight on top for devices that draw it; the flat body and the
	-- client-drawn marker carry the read on devices that do not.
	local highlight = Instance.new("Highlight")
	highlight.Name = "TargetHighlight"
	highlight.FillColor = style.FillColor
	highlight.OutlineColor = style.OutlineColor
	highlight.FillTransparency = style.FillTransparency
	highlight.OutlineTransparency = style.OutlineTransparency
	highlight.DepthMode = style.DepthMode
	highlight.Adornee = model
	highlight.Parent = model

	local animator = humanoid:WaitForChild("Animator")
	assert(animator:IsA("Animator"), "[OnboardingDummies] CharacterRig.Humanoid.Animator must be an Animator")
	local idle = animator:LoadAnimation(resolvedIdle())
	idle.Looped = true
	idle:Play()

	-- One-way projection of "this is a live target, and whose it is". The client
	-- draws the marker from this; nothing reads it back.
	model:SetAttribute(TARGET_ATTRIBUTE, ownerId)

	local extents = model:GetExtentsSize()
	local head = model:FindFirstChild("Head")

	local dummy: Dummy = {
		model = model,
		humanoid = humanoid,
		root = root,
		head = if head and head:IsA("BasePart") then head else root,
		radius = math.max(extents.X, extents.Z) * 0.5,
		knocked = false,
		repathAt = 0,
	}
	return dummy
end

function OnboardingDummies.isStanding(dummy: Dummy): boolean
	return not dummy.knocked and dummy.model.Parent ~= nil
end

function OnboardingDummies.position(dummy: Dummy): Vector3
	return dummy.root.Position
end

-- Walks the dummy at its learner, stopping a short way short so contact is the
-- player's choice. Humanoid:MoveTo gives up on its own after a few seconds, so
-- the periodic re-issue is what keeps it following rather than stalling.
local function chase(dummy: Dummy, target: Vector3, now: number)
	local training = OnboardingConfig.Training
	local toTarget = target - dummy.root.Position
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flat.Magnitude <= training.DummyStandoffStuds then
		dummy.humanoid:MoveTo(dummy.root.Position)
		return
	end
	if now < dummy.repathAt then
		return
	end
	dummy.repathAt = now + training.DummyRepathSeconds
	dummy.humanoid:MoveTo(target - flat.Unit * training.DummyStandoffStuds)
end

-- One per-frame entry point: a dummy presents itself, and chases only when it
-- has been given somewhere to go.
function OnboardingDummies.update(dummy: Dummy, now: number, chaseTarget: Vector3?)
	if not OnboardingDummies.isStanding(dummy) then
		return
	end
	if chaseTarget ~= nil then
		chase(dummy, chaseTarget, now)
	end
end

local function squash(dummy: Dummy)
	local width = dummy.humanoid:FindFirstChild("BodyWidthScale")
	local height = dummy.humanoid:FindFirstChild("BodyHeightScale")
	if not (width and width:IsA("NumberValue") and height and height:IsA("NumberValue")) then
		return
	end
	width.Value = 1.28
	height.Value = 0.72
	local tween = TweenInfo.new(0.34, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	TweenService:Create(width, tween, { Value = 1 }):Play()
	TweenService:Create(height, tween, { Value = 1 }):Play()
end

function OnboardingDummies.knock(dummy: Dummy, fromPosition: Vector3)
	if dummy.knocked then
		return
	end
	dummy.knocked = true

	local animator = dummy.humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop()
		end
	end
	dummy.humanoid.PlatformStand = true
	dummy.humanoid.WalkSpeed = 0

	-- A downed dummy is no longer a target, so it stops advertising itself.
	dummy.model:SetAttribute(TARGET_ATTRIBUTE, nil)
	local highlight = dummy.model:FindFirstChildOfClass("Highlight")
	if highlight then
		highlight.Enabled = false
	end

	for _, descendant in dummy.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end

	local away = dummy.root.Position - fromPosition
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 1, 0)
	end
	local direction = (away.Unit + Vector3.new(0, 1.6, 0)).Unit
	squash(dummy)
	dummy.root:ApplyImpulse(direction * dummy.root.AssemblyMass * 90)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local axis = if flat.Magnitude > 1e-3 then Vector3.new(0, 1, 0):Cross(flat.Unit) else Vector3.new(1, 0, 0)
	dummy.root:ApplyAngularImpulse((axis + Vector3.new(0, 0.25, 0)).Unit * dummy.root.AssemblyMass * 36)
end

function OnboardingDummies.destroy(dummy: Dummy)
	if dummy.model.Parent ~= nil then
		dummy.model:Destroy()
	end
end

return OnboardingDummies
