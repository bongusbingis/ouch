-- Top-cap landings bounce; side grazes receive one bounded outward roll-off.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(RS.Config.Gameplay.MapFeatures)
local Network = require(RS.Shared.Network)
local Guard = require(RS.Shared.Game.Adapters.MovementGuard)
local Parts = require(script.Parent.FeatureParts)
local Kit = require(script.Parent.MapFeatureKit)
local BigBalls = { folderName = "Rotating", instanceClass = "Folder" }
type Visit = {
	root: BasePart,
	ball: BasePart,
	attachment: Attachment?,
	expires: number,
	leftGround: boolean,
	bounced: boolean,
}
local balls: { BasePart } = {}
local visits: { [Player]: Visit } = {}
local cooldowns: { [Player]: number } = {}
local function clearForce(visit: Visit)
	if visit.attachment then
		visit.attachment:Destroy()
		visit.attachment = nil
	end
end
function BigBalls.tickWorld(context: Kit.Context)
	balls = Parts.collect(context.instances, Config.Attributes.BigBall)
end
function BigBalls.tickPlayer(context: Kit.Context, player: Player, root: BasePart)
	local humanoid = if root.Parent then root.Parent:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or root.Anchored then
		BigBalls.forget(player)
		return
	end
	local settings = Config.BigBall
	local visit = visits[player]
	if visit and (visit.root ~= root or not table.find(balls, visit.ball)) then
		BigBalls.forget(player)
		visit = nil
	end
	if visit then
		-- A later JumpPad owns its own float. Never stack two gravity cancellations.
		if visit.bounced and root:FindFirstChild("JumpPadFloatForce") then
			clearForce(visit)
		end
		if humanoid.FloorMaterial == Enum.Material.Air then
			visit.leftGround = true
		end
		if
			context.now >= visit.expires
			or (visit.bounced and visit.leftGround and humanoid.FloorMaterial ~= Enum.Material.Air)
		then
			clearForce(visit)
		end
	end
	local contact: BasePart? = nil
	local contactNormal = Vector3.yAxis
	for _, ball in balls do
		-- A capsule around the real root-to-feet span, not the sphere's box corners.
		local nearest = Vector3.new(
			root.Position.X,
			math.clamp(
				ball.Position.Y,
				root.Position.Y - humanoid.HipHeight - root.Size.Y / 2,
				root.Position.Y + root.Size.Y / 2
			),
			root.Position.Z
		)
		local radius = math.min(ball.Size.X, ball.Size.Y, ball.Size.Z) / 2
		if
			(nearest - ball.Position).Magnitude
			<= radius + math.min(root.Size.X, root.Size.Z) / 2 + settings.ContactPadding
		then
			contact = ball
			local normal = nearest - ball.Position
			contactNormal = if normal.Magnitude > 1e-3 then normal.Unit else ball.CFrame.UpVector
			break
		end
	end
	if visit and visit.ball ~= contact then
		-- Keep an airborne bounce's owned float until landing/expiry, even after leaving its sphere.
		if visit.bounced and visit.attachment and contact == nil then
			return
		end
		clearForce(visit)
		visits[player] = nil
		visit = nil
	end
	if not contact or visit or context.now < (cooldowns[player] or 0) then
		return
	end
	local ball = contact
	local offset = root.Position - ball.Position
	local cap = contactNormal:Dot(ball.CFrame.UpVector)
		>= math.cos(math.rad(Parts.number(ball, "CapDegrees", settings.CapDegrees, 10, 80)))
	local bounce = cap and root.AssemblyLinearVelocity.Y <= 5
	visit = { root = root, ball = ball, expires = context.now, leftGround = false, bounced = bounce }
	visits[player] = visit
	cooldowns[player] = context.now + Parts.number(ball, "RetriggerCooldown", settings.RetriggerCooldown, 0.1, 10)
	local attachment = Instance.new("Attachment")
	attachment.Name = if bounce then "BigBallFloatAttachment" else "BigBallShoveAttachment"
	attachment.Parent = root
	visit.attachment = attachment
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	if bounce then
		local speed = Parts.number(ball, "BounceSpeed", settings.BounceSpeed, 1, 160)
		local current = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(current.X, speed, current.Z)
		visit.expires = context.now + settings.MaxFloatSeconds
		-- Share the JumpPad float marker so a fan never doubles gravity cancellation.
		if not root:FindFirstChild("JumpPadFloatForce", true) then
			local force = Instance.new("VectorForce")
			force.Name = "JumpPadFloatForce"
			force.Attachment0 = attachment
			force.ApplyAtCenterOfMass = true
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.Force = Vector3.yAxis
				* root.AssemblyMass
				* Workspace.Gravity
				* Parts.number(ball, "FloatFactor", settings.FloatFactor, 0, 0.9)
			force.Parent = attachment
		end
		Guard.allow(root, "BigBall", settings.MaxFloatSeconds + 1, humanoid.WalkSpeed * 1.3, speed * 1.3, ball)
	else
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
		local speed = Parts.number(ball, "RollOffSpeed", settings.RollOffSpeed, 8, 80)
		local hold = Parts.number(ball, "ShoveSeconds", settings.ShoveSeconds, 0.08, 0.4)
		local target = direction * speed + Vector3.yAxis * math.max(root.AssemblyLinearVelocity.Y, settings.UpwardSpeed)
		root.AssemblyLinearVelocity = target
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.ForceLimitsEnabled = false
		velocity.VectorVelocity = target
		velocity.Parent = attachment
		visit.expires = context.now + hold
		Guard.allow(
			root,
			"BigBall",
			math.max(hold + 0.3, Parts.number(ball, "GuardSeconds", settings.GuardSeconds, 0.3, 10)),
			speed * 1.3,
			math.max(target.Y, 0) * 1.3,
			ball
		)
	end
	Network.fire("HazardVisual", nil, ball, "impact", 0.3)
end
function BigBalls.forget(player: Player?)
	if player then
		if visits[player] then
			clearForce(visits[player])
		end
		visits[player] = nil
		cooldowns[player] = nil
		return
	end
	for _, visit in visits do
		clearForce(visit)
	end
	table.clear(visits)
	table.clear(cooldowns)
	table.clear(balls)
end
return BigBalls
