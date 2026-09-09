-- Description: Gives the authored ring bumpers one bounded, damage-free radial push per player contact.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)

local Bumpers = {}
Bumpers.folderName = "Rotating"
Bumpers.instanceClass = "Folder"

type Visit = { root: BasePart, bumper: BasePart, bumped: boolean }
type Shove = { root: BasePart, bumper: BasePart, attachment: Attachment, expiresAt: number }

local contacts: { [BasePart]: BasePart } = {}
local activeBumpers: { [BasePart]: boolean } = {}
local bumpersByAssembly: { [Model]: { BasePart } } = {}
local visits: { [Player]: Visit } = {}
local shoves: { [Player]: Shove } = {}
local cooldowns: { [Player]: number } = {}
local roots: { Instance } = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function clearShove(player: Player)
	local shove = shoves[player]
	if shove then
		-- The velocity constraint is a child, so this destroys both owned objects.
		shove.attachment:Destroy()
		shoves[player] = nil
	end
end

local function bumpersFor(assembly: Model): { BasePart }
	local cached = bumpersByAssembly[assembly]
	if cached and #cached > 0 then
		return cached
	end
	local found: { BasePart } = {}
	for _, descendant in assembly:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		for _, prefix in MapFeatures.Bumper.NamePrefixes do
			if descendant.Name:find(prefix, 1, true) == 1 then
				table.insert(found, descendant)
				break
			end
		end
	end
	bumpersByAssembly[assembly] = found
	return found
end

function Bumpers.tickWorld(context: MapFeatureKit.Context)
	table.clear(contacts)
	table.clear(activeBumpers)
	table.clear(roots)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") and character:GetAttribute("CombatAlive") ~= false then
			table.insert(roots, root)
		end
	end
	overlap.FilterDescendantsInstances = roots
	if #roots == 0 then
		return
	end

	for _, group in context.instances do
		local assembly = group:FindFirstChild("Assembly")
		if assembly == nil or not assembly:IsA("Model") then
			continue
		end
		for _, bumper in bumpersFor(assembly) do
			activeBumpers[bumper] = true
			-- Inspect the actual mesh collision shape, not its bounding box.
			-- Root-only contact deliberately excludes cosmetic/limb grazing.
			for _, root in Workspace:GetPartsInPart(bumper, overlap) do
				contacts[root] = contacts[root] or bumper
			end
		end
	end
end

local function bump(
	context: MapFeatureKit.Context,
	player: Player,
	bumper: BasePart,
	root: BasePart,
	humanoid: Humanoid
)
	local settings = MapFeatures.Bumper
	local offset = root.Position - bumper.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local current = root.AssemblyLinearVelocity
	-- A target velocity, rather than an additive kick, prevents re-entry from
	-- stacking speed. A stronger fan/jump-pad ascent remains intact.
	local target = direction * settings.KnockbackSpeed + Vector3.yAxis * math.max(current.Y, settings.UpwardSpeed)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = target
	-- A brief hold clears the bumper before the normal controller slows the shove.
	-- It is never refreshed while the player remains in contact.
	local attachment = Instance.new("Attachment")
	attachment.Name = "BumperShoveAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "BumperShoveVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = target
	velocity.Parent = attachment
	shoves[player] = {
		root = root,
		bumper = bumper,
		attachment = attachment,
		expiresAt = context.now + settings.ShoveSeconds,
	}
	MovementGuard.allow(root, "Bumper", settings.GuardSeconds, settings.KnockbackSpeed * 1.3, target.Y * 1.3, bumper)
	Network.fire("BumperHit", nil, bumper)
end

function Bumpers.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid == nil
		or humanoid.Health <= 0
		or root.Anchored
		or (character and character:GetAttribute("CombatAlive") == false)
	then
		Bumpers.forget(player)
		return
	end

	local visit = visits[player]
	local shove = shoves[player]
	if (visit and visit.root ~= root) or (shove and shove.root ~= root) then
		Bumpers.forget(player)
		visit = nil
		shove = nil
	end
	if shove and (context.now >= shove.expiresAt or not activeBumpers[shove.bumper]) then
		clearShove(player)
	end
	local bumper = contacts[root]
	if visit and visit.bumper ~= bumper then
		visits[player] = nil
		visit = nil
	end
	if bumper == nil then
		return
	end
	if visit == nil then
		visit = { root = root, bumper = bumper, bumped = false }
		visits[player] = visit
	end
	if not visit.bumped and shoves[player] == nil and context.now >= (cooldowns[player] or 0) then
		visit.bumped = true
		cooldowns[player] = context.now + MapFeatures.Bumper.RetriggerCooldown
		bump(context, player, bumper, root, humanoid)
	end
end

function Bumpers.forget(player: Player?)
	if player then
		clearShove(player)
		local visit = visits[player]
		if visit then
			contacts[visit.root] = nil
		end
		visits[player] = nil
		cooldowns[player] = nil
		return
	end
	for existing in shoves do
		clearShove(existing)
	end
	table.clear(contacts)
	table.clear(activeBumpers)
	table.clear(visits)
	table.clear(cooldowns)
	table.clear(roots)
	overlap.FilterDescendantsInstances = {}
end

return Bumpers
