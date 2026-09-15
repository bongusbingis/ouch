-- Description: Gives every attribute-declared rotor that asks for it one bounded, damage-free push per player contact, in the direction the rotor's surface is moving at the point of contact, so spinners, maces, hammers, paddle wheels, windmill bars and rollers all share one shove.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local MovementGuard = require(Game:WaitForChild("Adapters"):WaitForChild("MovementGuard"))
local RotatingPlatforms = require(Game:WaitForChild("MapFeatures"):WaitForChild("RotatingPlatforms"))
local MapFeatureKit = require(script.Parent.MapFeatureKit)
local ShoveTuning = require(Game.MapFeatures.ShoveTuning)

local RotorBump = {}
RotorBump.folderName = "Rotating"
RotorBump.instanceClass = "Folder"

type Contact = {
	platform: RotatingPlatforms.Platform,
	rotor: RotatingPlatforms.LocalRotor,
	part: BasePart,
}
type Visit = { root: BasePart, rotor: RotatingPlatforms.LocalRotor, bumped: boolean }
type Shove = { root: BasePart, rotor: RotatingPlatforms.LocalRotor, attachment: Attachment, expiresAt: number }

local contacts: { [BasePart]: Contact } = {}
local activeRotors: { [RotatingPlatforms.LocalRotor]: boolean } = {}
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

local function testPart(platform: RotatingPlatforms.Platform, rotor: RotatingPlatforms.LocalRotor, part: BasePart)
	if part.Parent == nil then
		return
	end
	-- Root-only contact excludes cosmetic/limb grazing. A small padded
	-- oriented box makes near-edge contacts register more reliably.
	local padding = Vector3.one * MapFeatures.RotorBump.ContactPadding * 2
	for _, root in Workspace:GetPartBoundsInBox(part.CFrame, part.Size + padding, overlap) do
		if contacts[root] == nil then
			contacts[root] = { platform = platform, rotor = rotor, part = part }
		end
	end
end

function RotorBump.tickWorld(_context: MapFeatureKit.Context)
	table.clear(contacts)
	table.clear(activeRotors)
	table.clear(roots)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			character
			and root
			and root:IsA("BasePart")
			and not root.Anchored
			and character:GetAttribute("CombatAlive") ~= false
		then
			table.insert(roots, root)
		end
	end
	overlap.FilterDescendantsInstances = roots
	if #roots == 0 then
		return
	end

	for _, platform in RotatingPlatforms.all() do
		for _, rotor in platform.localRotors do
			if not rotor.shove then
				continue
			end
			activeRotors[rotor] = true
			testPart(platform, rotor, rotor.part)
			for _, follower in rotor.followers do
				testPart(platform, rotor, follower.part)
			end
		end
	end
end

local function bump(
	context: MapFeatureKit.Context,
	player: Player,
	contact: Contact,
	root: BasePart,
	humanoid: Humanoid
)
	local settings = MapFeatures.RotorBump
	local attributes = MapFeatures.Attributes
	local response = ShoveTuning.resolve(
		settings,
		contact.rotor.shoveSpeed,
		contact.rotor.part:GetAttribute(attributes.ShoveUpwardSpeed),
		contact.rotor.part:GetAttribute(attributes.ShoveSeconds)
	)
	local now = Workspace:GetServerTimeNow()
	local center = RotatingPlatforms.rotorPoseAt(contact.platform, contact.rotor, now).Position
	local offset = root.Position - center
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local outward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local surface = RotatingPlatforms.surfaceVelocityAt(contact.platform, contact.rotor, root.Position, now)
	local flatSurface = Vector3.new(surface.X, 0, surface.Z)
	local direction = if flatSurface.Magnitude >= settings.MinimumSurfaceSpeed
		then (flatSurface.Unit + outward * settings.OutwardBias).Unit
		else outward
	local speed = response.KnockbackSpeed
	local current = root.AssemblyLinearVelocity
	-- A target velocity, rather than an additive kick, prevents re-entry from
	-- stacking speed. A stronger fan/jump-pad ascent remains intact.
	local target = direction * speed + Vector3.yAxis * math.max(current.Y, response.UpwardSpeed)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = target
	-- A brief hold clears the moving part before the normal controller slows
	-- the shove. It is never refreshed while the player remains in contact.
	local attachment = Instance.new("Attachment")
	attachment.Name = "RotorShoveAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "RotorShoveVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = target
	velocity.Parent = attachment
	shoves[player] = {
		root = root,
		rotor = contact.rotor,
		attachment = attachment,
		expiresAt = context.now + response.ShoveSeconds,
	}
	MovementGuard.allow(root, "RotorBump", response.GuardSeconds, speed * 1.3, target.Y * 1.3, contact.part)
end

function RotorBump.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid == nil
		or humanoid.Health <= 0
		or root.Anchored
		or (character and character:GetAttribute("CombatAlive") == false)
	then
		RotorBump.forget(player)
		return
	end

	local visit = visits[player]
	local shove = shoves[player]
	if (visit and visit.root ~= root) or (shove and shove.root ~= root) then
		RotorBump.forget(player)
		visit = nil
		shove = nil
	end
	if shove and (context.now >= shove.expiresAt or not activeRotors[shove.rotor]) then
		clearShove(player)
	end
	local contact = contacts[root]
	local rotor = if contact then contact.rotor else nil
	if visit and visit.rotor ~= rotor then
		visits[player] = nil
		visit = nil
	end
	if contact == nil or rotor == nil then
		return
	end
	if visit == nil then
		visit = { root = root, rotor = rotor, bumped = false }
		visits[player] = visit
	end
	if not visit.bumped and shoves[player] == nil and context.now >= (cooldowns[player] or 0) then
		visit.bumped = true
		cooldowns[player] = context.now + MapFeatures.RotorBump.RetriggerCooldown
		bump(context, player, contact, root, humanoid)
	end
end

function RotorBump.forget(player: Player?)
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
	table.clear(activeRotors)
	table.clear(visits)
	table.clear(cooldowns)
	table.clear(roots)
	overlap.FilterDescendantsInstances = {}
end

return RotorBump
