-- Description: Gives authored fans continuous, bounded airflow while preserving horizontal steering.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)
local Parts = require(script.Parent.FeatureParts)
local BeachBalls = require(script.Parent.BeachBalls)

local FanUpdraft = {}
FanUpdraft.folderName = "Rotating"
FanUpdraft.folderNames = { "Fans", "Rotating" }
FanUpdraft.instanceClass = "Folder"

type Visit = {
	root: BasePart,
	fan: BasePart,
	force: VectorForce?,
	attachment: Attachment?,
}

local fans: { BasePart } = {}
local fansByAssembly: { [Instance]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any
local visits: { [Player]: Visit } = {}

-- Authored arena fans are named; course fans carry the attribute. Scanned once
-- per assembly because a course assembly holds hundreds of parts.
local function fansFor(assembly: Instance): { BasePart }
	local cached = fansByAssembly[assembly]
	if cached then
		return cached
	end
	local found: { BasePart } = {}
	local allowLegacy = assembly:FindFirstAncestor("SplashdownCourse") == nil
	for _, descendant in assembly:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and (
				(allowLegacy and MapFeatures.Fan.EnabledNames[descendant.Name] == true)
				or descendant:GetAttribute(MapFeatures.Attributes.Fan) == true
			)
		then
			table.insert(found, descendant)
		end
	end
	fansByAssembly[assembly] = found
	return found
end

local function clearLift(visit: Visit)
	if visit.force then
		visit.force:Destroy()
		visit.force = nil
	end
	if visit.attachment then
		visit.attachment:Destroy()
		visit.attachment = nil
	end
end

local function clearVisit(player: Player)
	local visit = visits[player]
	if visit then
		clearLift(visit)
		visits[player] = nil
	end
end

local function heightInColumn(fan: BasePart, root: BasePart): number?
	local settings = MapFeatures.Fan
	-- MeshPart.CFrame follows the moving ring. Imported PivotOffsets are not the
	-- grate's orientation and must not define the gameplay volume.
	local offset = fan.CFrame:PointToObjectSpace(root.Position)
	local axis = fan:GetAttribute(MapFeatures.Attributes.FanAxis)
	if axis ~= nil then
		local fanAxis = Parts.axis(fan, "FanAxis", "Y")
		local direction = fanAxis * Parts.number(fan, "FanDirection", 1)
		local axial = offset:Dot(direction)
		local half = fan.Size:Dot(fanAxis) / 2
		local transverse = offset - direction * axial
		local radius = (
			if axis == "X"
				then math.min(fan.Size.Y, fan.Size.Z)
				elseif axis == "Z" then math.min(fan.Size.X, fan.Size.Y)
				else math.min(fan.Size.X, fan.Size.Z)
		)
			/ 2
			* settings.RadiusScale
		local height = axial - half
		if
			height >= -settings.BottomTolerance
			and height <= Parts.number(fan, "FanColumnHeight", settings.ColumnHeight)
			and transverse.Magnitude <= radius
		then
			return height
		end
		return nil
	end
	local height = offset.Y - fan.Size.Y / 2
	local radius = math.min(fan.Size.X, fan.Size.Z) / 2 * settings.RadiusScale
	if
		height >= -settings.BottomTolerance
		and height <= settings.ColumnHeight
		and offset.X * offset.X + offset.Z * offset.Z <= radius * radius
	then
		return height
	end
	return nil
end

function FanUpdraft.tickWorld(context: MapFeatureKit.Context)
	table.clear(fans)
	for _, group in context.instances do
		for _, fan in fansFor(group) do
			if fan.Parent ~= nil then
				table.insert(fans, fan)
			end
		end
	end
	for _, ball in BeachBalls.active() do
		for _, fan in fans do
			if fan:GetAttribute(MapFeatures.Attributes.Fan) == true and heightInColumn(fan, ball) ~= nil then
				local direction = fan.CFrame:VectorToWorldSpace(Parts.axis(fan, "FanAxis", "Y"))
					* Parts.number(fan, "FanDirection", 1)
				local deficit = Parts.number(fan, "FanBallSpeed", MapFeatures.CourseFan.BallSpeed)
					- ball.AssemblyLinearVelocity:Dot(direction)
				if deficit > 0 then
					ball:ApplyImpulse(
						direction
							* ball.AssemblyMass
							* math.min(deficit, MapFeatures.CourseFan.BallAcceleration * context.deltaTime)
					)
				end
			end
		end
	end
end

local function lift(visit: Visit, humanoid: Humanoid)
	local settings = MapFeatures.Fan
	local root = visit.root
	local targetSpeed = Parts.number(visit.fan, "LaunchSpeed", settings.LaunchSpeed) * settings.LiftSpeedScale
	local direction = if visit.fan:GetAttribute("FanAxis") ~= nil
		then visit.fan.CFrame:VectorToWorldSpace(Parts.axis(visit.fan, "FanAxis", "Y")) * Parts.number(
			visit.fan,
			"FanDirection",
			1
		)
		else Vector3.yAxis
	local guardSeconds = Parts.number(visit.fan, "GuardSeconds", settings.GuardSeconds)
	local floatFactor = Parts.number(visit.fan, "FloatFactor", settings.FloatFactor)
	local response = settings.LiftResponseSeconds * (1 - 0.3 * floatFactor)
	local acceleration = math.clamp(
		(targetSpeed - root.AssemblyLinearVelocity:Dot(direction)) / response,
		-settings.MaxLiftAcceleration,
		settings.MaxLiftAcceleration
	)

	local force = visit.force
	if force == nil then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		local attachment = Instance.new("Attachment")
		attachment.Name = "FanFloatAttachment"
		attachment.Parent = root
		force = Instance.new("VectorForce")
		force.Name = "FanFloatForce"
		force.Attachment0 = attachment
		force.ApplyAtCenterOfMass = true
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Parent = root
		visit.attachment = attachment
		visit.force = force
	end

	-- Counter gravity in the column, then smoothly approach the directional
	-- airflow speed. No velocity is assigned on entry or re-entry.
	force.Force = root.AssemblyMass * (Vector3.yAxis * Workspace.Gravity + direction * acceleration)
	MovementGuard.allow(
		root,
		"Fan",
		guardSeconds,
		if direction.Y < 0.99 then targetSpeed * 1.5 else 0,
		targetSpeed * 1.5
	)
end

function FanUpdraft.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid == nil
		or humanoid.Health <= 0
		or humanoid.PlatformStand
		or humanoid:GetState() == Enum.HumanoidStateType.Physics
		or root.Anchored
		or (character and character:GetAttribute("CombatAlive") == false)
	then
		FanUpdraft.forget(player)
		return
	end

	local visit = visits[player]
	if visit and visit.root ~= root then
		FanUpdraft.forget(player)
		visit = nil
	end

	local currentFan: BasePart? = nil
	for _, fan in fans do
		local height = heightInColumn(fan, root)
		if height ~= nil then
			currentFan = fan
			break
		end
	end
	if visit and visit.fan ~= currentFan then
		clearVisit(player)
		visit = nil
	end
	if currentFan == nil then
		return
	end
	-- A jump pad may carry a player through the same column. Its own float force
	-- and trajectory take precedence until that effect expires.
	if root:FindFirstChild("JumpPadFloatForce", true) then
		if visit then
			clearLift(visit)
		end
		return
	end
	if visit == nil then
		visit = {
			root = root,
			fan = currentFan,
		}
		visits[player] = visit
	end
	lift(visit, humanoid)
end

function FanUpdraft.forget(player: Player?)
	if player then
		clearVisit(player)
		return
	end
	for existing in visits do
		clearVisit(existing)
	end
	table.clear(fans)
end

return FanUpdraft
