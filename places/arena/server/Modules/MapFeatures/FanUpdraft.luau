-- Description: Gives the authored fans a bounded upward launch and local airflow while preserving horizontal steering.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)

local FanUpdraft = {}
FanUpdraft.folderName = "Rotating"
FanUpdraft.instanceClass = "Folder"

type Visit = {
	root: BasePart,
	fan: BasePart,
	launched: boolean,
	expiresAt: number,
	force: VectorForce?,
	attachment: Attachment?,
}

local fans: { BasePart } = {}
local visits: { [Player]: Visit } = {}
local cooldowns: { [Player]: number } = {}

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
		local assembly = group:FindFirstChild("Assembly")
		if assembly and assembly:IsA("Model") then
			for name, enabled in MapFeatures.Fan.EnabledNames do
				local fan = if enabled then assembly:FindFirstChild(name) else nil
				if fan and fan:IsA("BasePart") then
					table.insert(fans, fan)
				end
			end
		end
	end
end

local function launch(context: MapFeatureKit.Context, visit: Visit, humanoid: Humanoid)
	local settings = MapFeatures.Fan
	local root = visit.root
	visit.launched = true
	visit.expiresAt = context.now + settings.MaxLiftSeconds

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local velocity = root.AssemblyLinearVelocity
	-- Setting a floor rather than adding an impulse prevents speed stacking on
	-- re-entry and preserves any stronger launch owned by another mechanic.
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, settings.LaunchSpeed), velocity.Z)
	MovementGuard.allow(root, "Fan", settings.GuardSeconds, 0, settings.LaunchSpeed * 1.3)

	-- JumpPads owns its longer float effect. Never add a second gravity cancel
	-- to it or destroy its constraints when leaving the fan.
	if root:FindFirstChild("JumpPadFloatForce") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FanFloatAttachment"
	attachment.Parent = root
	local force = Instance.new("VectorForce")
	force.Name = "FanFloatForce"
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = true
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * settings.FloatFactor, 0)
	force.Parent = root
	visit.attachment = attachment
	visit.force = force
end

function FanUpdraft.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid == nil
		or humanoid.Health <= 0
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
	local currentHeight: number? = nil
	for _, fan in fans do
		local height = heightInColumn(fan, root)
		if height ~= nil then
			currentFan = fan
			currentHeight = height
			break
		end
	end
	if visit and visit.fan ~= currentFan then
		clearVisit(player)
		visit = nil
	end
	if currentFan == nil or currentHeight == nil then
		return
	end
	if visit == nil then
		visit = {
			root = root,
			fan = currentFan,
			launched = false,
			expiresAt = 0,
		}
		visits[player] = visit
	end
	if visit.force and (context.now >= visit.expiresAt or root:FindFirstChild("JumpPadFloatForce")) then
		clearLift(visit)
	end
	if
		not visit.launched
		and currentHeight <= MapFeatures.Fan.EntryHeight
		and context.now >= (cooldowns[player] or 0)
	then
		cooldowns[player] = context.now + MapFeatures.Fan.RetriggerCooldown
		launch(context, visit, humanoid)
	end
end

function FanUpdraft.forget(player: Player?)
	if player then
		clearVisit(player)
		cooldowns[player] = nil
		return
	end
	for existing in visits do
		clearVisit(existing)
	end
	table.clear(cooldowns)
	table.clear(fans)
end

return FanUpdraft
